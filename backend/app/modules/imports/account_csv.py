import csv
import hashlib
import io
import re
import unicodedata
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import ImportBatch, Transaction

from app.modules.categories.service import (
    bootstrap_default_rules,
    categorize_transaction,
)


NUBANK_ACCOUNT_SOURCE_FORMAT = "nubank_account_statement_v1"
EXPECTED_HEADERS = {"Data", "Valor", "Identificador", "Descrição"}


@dataclass
class ProcessedAccountCsv:
    file_name: str
    file_hash: str
    source_format: str
    period_start: date | None
    period_end: date | None
    total_rows: int
    valid_rows: int
    error_rows: int
    transactions: list[dict[str, Any]]
    errors: list[str]
    warnings: list[str]


def calculate_file_hash(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def normalize_text(value: str | None) -> str:
    if value is None:
        return ""

    normalized = unicodedata.normalize("NFKD", value)
    normalized = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    normalized = normalized.lower().strip()
    normalized = re.sub(r"\s+", " ", normalized)

    return normalized


def normalize_description_for_hash(value: str | None) -> str:
    text = normalize_text(value)
    text = re.sub(r"[^\w\s\-@*.]", "", text)
    text = re.sub(r"\s+", " ", text).strip()

    return text


def detect_csv_encoding(content: bytes) -> str:
    for encoding in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            content.decode(encoding)
            return encoding
        except UnicodeDecodeError:
            continue

    raise ValueError("Não foi possível detectar a codificação do arquivo CSV.")


def read_csv_rows(content: bytes) -> list[dict[str, str]]:
    encoding = detect_csv_encoding(content)
    text = content.decode(encoding)

    sample = text[:2048]

    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;")
        delimiter = dialect.delimiter
    except csv.Error:
        delimiter = ","

    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)

    if reader.fieldnames is None:
        raise ValueError("O arquivo CSV não possui cabeçalho.")

    headers = {header.strip() for header in reader.fieldnames if header is not None}

    if not EXPECTED_HEADERS.issubset(headers):
        raise ValueError(
            "Formato de CSV inválido. Esperado: Data, Valor, Identificador, Descrição."
        )

    rows: list[dict[str, str]] = []

    for row in reader:
        if not row:
            continue

        cleaned_row = {
            str(key).strip(): str(value).strip()
            for key, value in row.items()
            if key is not None and value is not None
        }

        if any(cleaned_row.values()):
            rows.append(cleaned_row)

    return rows


def parse_nubank_account_date(value: str) -> date:
    try:
        return datetime.strptime(value.strip(), "%d/%m/%Y").date()
    except ValueError as error:
        raise ValueError(f"Data inválida: {value}") from error


def parse_money_value(value: str) -> Decimal:
    cleaned = value.strip()
    cleaned = cleaned.replace("R$", "").replace(" ", "")

    # Conta Nubank geralmente usa ponto decimal: -153.90
    # Mas deixamos suporte para vírgula por segurança.
    if "," in cleaned and "." in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    elif "," in cleaned:
        cleaned = cleaned.replace(",", ".")

    try:
        return Decimal(cleaned)
    except InvalidOperation as error:
        raise ValueError(f"Valor inválido: {value}") from error


def extract_bank_details(text: str) -> dict[str, str | None]:
    bank_code = None
    agency = None
    account = None

    bank_code_match = re.search(r"\((\d{3,4})\)", text)
    agency_match = re.search(r"Ag[eê]ncia:\s*([^\s]+)", text, flags=re.IGNORECASE)
    account_match = re.search(r"Conta:\s*([^\s]+)", text, flags=re.IGNORECASE)

    if bank_code_match:
        bank_code = bank_code_match.group(1)

    if agency_match:
        agency = agency_match.group(1)

    if account_match:
        account = account_match.group(1)

    return {
        "counterparty_bank_code": bank_code,
        "counterparty_agency": agency,
        "counterparty_account": account,
    }


def clean_institution_name(value: str | None) -> str | None:
    if not value:
        return None

    cleaned = re.sub(r"\(\d{3,4}\)", "", value)
    cleaned = re.sub(r"Ag[eê]ncia:.*", "", cleaned, flags=re.IGNORECASE)
    cleaned = cleaned.strip(" -")

    return cleaned or None


def parse_nubank_account_description(description: str) -> dict[str, Any]:
    raw = description.strip()
    raw_lower = normalize_text(raw)
    parts = [part.strip() for part in raw.split(" - ") if part.strip()]

    parsed: dict[str, Any] = {
        "operation_type": "unknown",
        "payment_method": "unknown",
        "description": "Transação",
        "display_description": raw,
        "counterparty_name": None,
        "counterparty_document": None,
        "counterparty_institution": None,
        "counterparty_bank_code": None,
        "counterparty_agency": None,
        "counterparty_account": None,
        "merchant_name": None,
    }

    if raw_lower.startswith("transferencia recebida pelo pix"):
        parsed["operation_type"] = "pix_received"
        parsed["payment_method"] = "pix"
        parsed["description"] = "Pix recebido"

        if len(parts) > 1:
            parsed["counterparty_name"] = parts[1]
            parsed["display_description"] = f"Pix recebido de {parts[1]}"
        else:
            parsed["display_description"] = "Pix recebido"

        if len(parts) > 2:
            parsed["counterparty_document"] = parts[2]

        if len(parts) > 3:
            parsed["counterparty_institution"] = clean_institution_name(parts[3])

        parsed.update(extract_bank_details(raw))

        return parsed

    if raw_lower.startswith("transferencia enviada pelo pix"):
        parsed["operation_type"] = "pix_sent"
        parsed["payment_method"] = "pix"
        parsed["description"] = "Pix enviado"

        if len(parts) > 1:
            parsed["counterparty_name"] = parts[1]
            parsed["display_description"] = f"Pix enviado para {parts[1]}"
        else:
            parsed["display_description"] = "Pix enviado"

        if len(parts) > 2:
            parsed["counterparty_document"] = parts[2]

        if len(parts) > 3:
            parsed["counterparty_institution"] = clean_institution_name(parts[3])

        parsed.update(extract_bank_details(raw))

        return parsed

    if raw_lower.startswith("compra no debito"):
        parsed["operation_type"] = "debit_purchase"
        parsed["payment_method"] = "debit_card"
        parsed["description"] = "Compra no débito"

        merchant = parts[1] if len(parts) > 1 else raw.replace("Compra no débito", "").strip(" -")
        parsed["merchant_name"] = merchant or None
        parsed["display_description"] = (
            f"Compra no débito - {merchant}" if merchant else "Compra no débito"
        )

        return parsed

    if raw_lower.startswith("pagamento de boleto efetuado"):
        parsed["operation_type"] = "bank_slip_payment"
        parsed["payment_method"] = "bank_slip"
        parsed["description"] = "Pagamento de boleto"

        merchant = parts[1] if len(parts) > 1 else raw.replace("Pagamento de boleto efetuado", "").strip(" -")
        parsed["merchant_name"] = merchant or None
        parsed["display_description"] = (
            f"Pagamento de boleto - {merchant}" if merchant else "Pagamento de boleto"
        )

        return parsed

    if raw_lower.startswith("pagamento de fatura"):
        parsed["operation_type"] = "credit_card_bill_payment"
        parsed["payment_method"] = "credit_card_bill"
        parsed["description"] = "Pagamento de fatura"
        parsed["display_description"] = "Pagamento de fatura"

        return parsed

    if raw_lower.startswith("valor adicionado na conta por cartao de credito"):
        parsed["operation_type"] = "credit_card_funding"
        parsed["payment_method"] = "credit_card_to_account"
        parsed["description"] = "Valor adicionado por cartão de crédito"
        parsed["display_description"] = "Valor adicionado por cartão de crédito"

        return parsed

    if raw_lower.startswith("transferencia recebida"):
        parsed["operation_type"] = "transfer_received"
        parsed["payment_method"] = "transfer"
        parsed["description"] = "Transferência recebida"

        if len(parts) > 1:
            parsed["counterparty_name"] = parts[1]
            parsed["display_description"] = f"Transferência recebida de {parts[1]}"
        else:
            parsed["display_description"] = "Transferência recebida"

        parsed.update(extract_bank_details(raw))

        return parsed

    if raw_lower.startswith("transferencia enviada"):
        parsed["operation_type"] = "transfer_sent"
        parsed["payment_method"] = "transfer"
        parsed["description"] = "Transferência enviada"

        if len(parts) > 1:
            parsed["counterparty_name"] = parts[1]
            parsed["display_description"] = f"Transferência enviada para {parts[1]}"
        else:
            parsed["display_description"] = "Transferência enviada"

        parsed.update(extract_bank_details(raw))

        return parsed

    return parsed


def classify_account_cash_direction(amount: Decimal) -> str:
    if amount > 0:
        return "inflow"

    if amount < 0:
        return "outflow"

    return "none"


def classify_account_cashflow_type(amount: Decimal, operation_type: str) -> str:
    if operation_type == "credit_card_funding":
        return "liability_increase"

    if operation_type == "credit_card_bill_payment":
        return "debt_payment"

    if operation_type in {"debit_purchase", "bank_slip_payment"}:
        return "expense"

    if operation_type in {"pix_sent", "transfer_sent"}:
        return "expense"

    if operation_type in {"pix_received", "transfer_received"}:
        return "income"

    if amount > 0:
        return "income"

    if amount < 0:
        return "expense"

    return "unknown"


def generate_account_transaction_fingerprint(
    transaction: dict[str, Any],
    account_id: int,
) -> str:
    raw_description = normalize_description_for_hash(
        transaction.get("raw_description")
    )

    base = "|".join(
        [
            str(account_id),
            str(transaction["date"]),
            str(transaction["amount"]),
            str(transaction.get("external_id") or ""),
            raw_description,
        ]
    )

    return hashlib.sha256(base.encode("utf-8")).hexdigest()


def normalize_nubank_account_row(
    raw_row: dict[str, str],
    account_id: int,
    row_index: int,
) -> dict[str, Any]:
    transaction_date = parse_nubank_account_date(raw_row["Data"])
    amount = parse_money_value(raw_row["Valor"])
    raw_description = raw_row["Descrição"].strip()
    external_id = raw_row.get("Identificador", "").strip() or None

    parsed_description = parse_nubank_account_description(raw_description)

    cash_direction = classify_account_cash_direction(amount)
    operation_type = parsed_description["operation_type"]
    cashflow_type = classify_account_cashflow_type(amount, operation_type)

    transaction: dict[str, Any] = {
        "date": transaction_date,
        "amount": amount,
        "amount_abs": abs(amount),
        "account_type": "checking",
        "source": "csv",
        "source_format": NUBANK_ACCOUNT_SOURCE_FORMAT,
        "description": parsed_description["description"],
        "display_description": parsed_description["display_description"],
        "raw_description": raw_description,
        "cash_direction": cash_direction,
        "liability_direction": "none",
        "cashflow_type": cashflow_type,
        "operation_type": operation_type,
        "payment_method": parsed_description["payment_method"],
        "merchant_name": parsed_description["merchant_name"],
        "counterparty_name": parsed_description["counterparty_name"],
        "counterparty_document": parsed_description["counterparty_document"],
        "counterparty_institution": parsed_description["counterparty_institution"],
        "counterparty_bank_code": parsed_description["counterparty_bank_code"],
        "counterparty_agency": parsed_description["counterparty_agency"],
        "counterparty_account": parsed_description["counterparty_account"],
        "external_id": external_id,
        "is_card_payment": False,
        "is_reconciled": False,
        "reconciliation_status": "pending",
        "is_internal_transfer": False,
        "related_external_id": None,
        "metadata_json": {
            "row_index": row_index,
        },
    }

    transaction["fingerprint"] = generate_account_transaction_fingerprint(
        transaction=transaction,
        account_id=account_id,
    )

    return transaction


def detect_repeated_external_ids(transactions: list[dict[str, Any]]) -> set[str]:
    seen: set[str] = set()
    repeated: set[str] = set()

    for transaction in transactions:
        external_id = transaction.get("external_id")

        if not external_id:
            continue

        if external_id in seen:
            repeated.add(external_id)
        else:
            seen.add(external_id)

    return repeated


def process_account_csv(
    file_name: str,
    content: bytes,
    account_id: int,
) -> ProcessedAccountCsv:
    file_hash = calculate_file_hash(content)
    rows = read_csv_rows(content)

    transactions: list[dict[str, Any]] = []
    errors: list[str] = []
    warnings: list[str] = []

    for index, row in enumerate(rows, start=1):
        try:
            transaction = normalize_nubank_account_row(
                raw_row=row,
                account_id=account_id,
                row_index=index,
            )
            transactions.append(transaction)
        except (KeyError, ValueError) as error:
            errors.append(f"Linha {index}: {error}")

    repeated_external_ids = detect_repeated_external_ids(transactions)

    if repeated_external_ids:
        for transaction in transactions:
            external_id = transaction.get("external_id")

            if external_id in repeated_external_ids:
                transaction["related_external_id"] = external_id

        warnings.append(
            "Há identificadores externos repetidos. Eles serão tratados como transações relacionadas, não como duplicatas."
        )

    dates = [transaction["date"] for transaction in transactions]

    period_start = min(dates) if dates else None
    period_end = max(dates) if dates else None

    return ProcessedAccountCsv(
        file_name=file_name,
        file_hash=file_hash,
        source_format=NUBANK_ACCOUNT_SOURCE_FORMAT,
        period_start=period_start,
        period_end=period_end,
        total_rows=len(rows),
        valid_rows=len(transactions),
        error_rows=len(errors),
        transactions=transactions,
        errors=errors,
        warnings=warnings,
    )


def build_preview_summary(processed: ProcessedAccountCsv) -> dict[str, Any]:
    transactions = processed.transactions

    gross_inflow = sum(
        transaction["amount"]
        for transaction in transactions
        if transaction["cash_direction"] == "inflow"
    )

    gross_outflow = sum(
        transaction["amount_abs"]
        for transaction in transactions
        if transaction["cash_direction"] == "outflow"
    )

    net_cashflow = sum(transaction["amount"] for transaction in transactions)

    income = sum(
        transaction["amount"]
        for transaction in transactions
        if transaction["cashflow_type"] == "income"
    )

    expenses = sum(
        transaction["amount_abs"]
        for transaction in transactions
        if transaction["cashflow_type"] == "expense"
    )

    debt_payments = sum(
        transaction["amount_abs"]
        for transaction in transactions
        if transaction["cashflow_type"] == "debt_payment"
    )

    liability_increase = sum(
        transaction["amount"]
        for transaction in transactions
        if transaction["cashflow_type"] == "liability_increase"
    )

    operation_types = sorted(
        {
            transaction["operation_type"]
            for transaction in transactions
            if transaction["operation_type"]
        }
    )

    sample_transactions = transactions[:10]

    return {
        "file_name": processed.file_name,
        "format": processed.source_format,
        "period_start": processed.period_start,
        "period_end": processed.period_end,
        "total_rows": processed.total_rows,
        "valid_rows": processed.valid_rows,
        "error_rows": processed.error_rows,
        "gross_inflow": gross_inflow,
        "gross_outflow": gross_outflow,
        "net_cashflow": net_cashflow,
        "income": income,
        "expenses": expenses,
        "debt_payments": debt_payments,
        "liability_increase": liability_increase,
        "operation_types": operation_types,
        "warnings": processed.warnings,
        "sample_transactions": [
            {
                "date": transaction["date"],
                "amount": transaction["amount"],
                "direction": transaction["cash_direction"],
                "cashflow_type": transaction["cashflow_type"],
                "operation_type": transaction["operation_type"],
                "payment_method": transaction["payment_method"],
                "display_description": transaction["display_description"],
                "raw_description": transaction["raw_description"],
                "external_id": transaction["external_id"],
            }
            for transaction in sample_transactions
        ],
    }


def find_existing_import_batch(
    db: Session,
    user_id: int,
    account_id: int,
    file_hash: str,
) -> ImportBatch | None:
    statement = (
        select(ImportBatch)
        .where(ImportBatch.user_id == user_id)
        .where(ImportBatch.account_id == account_id)
        .where(ImportBatch.file_hash == file_hash)
    )

    return db.scalar(statement)


def find_existing_fingerprints(
    db: Session,
    fingerprints: list[str],
) -> set[str]:
    if not fingerprints:
        return set()

    statement = select(Transaction.fingerprint).where(
        Transaction.fingerprint.in_(fingerprints)
    )

    return set(db.scalars(statement).all())


def create_import_batch(
    db: Session,
    user_id: int,
    account_id: int,
    processed: ProcessedAccountCsv,
    status: str = "processing",
) -> ImportBatch:
    import_batch = ImportBatch(
        user_id=user_id,
        account_id=account_id,
        file_name=processed.file_name,
        file_hash=processed.file_hash,
        source="csv",
        source_format=processed.source_format,
        period_start=processed.period_start,
        period_end=processed.period_end,
        total_rows=processed.total_rows,
        imported_rows=0,
        duplicate_rows=0,
        error_rows=processed.error_rows,
        status=status,
    )

    db.add(import_batch)
    db.flush()

    return import_batch


def save_account_csv_transactions(
    db: Session,
    user_id: int,
    account_id: int,
    processed: ProcessedAccountCsv,
) -> dict[str, Any]:
    existing_batch = find_existing_import_batch(
        db=db,
        user_id=user_id,
        account_id=account_id,
        file_hash=processed.file_hash,
    )

    if existing_batch is not None:
        raise ValueError("Este arquivo CSV já foi importado para esta conta.")

    import_batch = create_import_batch(
        db=db,
        user_id=user_id,
        account_id=account_id,
        processed=processed,
    )

    fingerprints = [
        transaction["fingerprint"]
        for transaction in processed.transactions
    ]

    existing_fingerprints = find_existing_fingerprints(
        db=db,
        fingerprints=fingerprints,
    )

    imported_count = 0
    duplicate_count = 0
    bootstrap_default_rules(
        db=db,
        user_id=user_id,
    )

    for transaction_data in processed.transactions:
        if transaction_data["fingerprint"] in existing_fingerprints:
            duplicate_count += 1
            continue

        transaction = Transaction(
            user_id=user_id,
            account_id=account_id,
            import_batch_id=import_batch.id,
            **transaction_data,
        )

        db.add(transaction)

        categorize_transaction(
            db=db,
            user_id=user_id,
            transaction=transaction,
        )

        imported_count += 1

    import_batch.imported_rows = imported_count
    import_batch.duplicate_rows = duplicate_count
    import_batch.error_rows = processed.error_rows
    import_batch.status = "completed" if not processed.errors else "completed_with_errors"

    db.commit()
    db.refresh(import_batch)

    return {
        "import_batch": import_batch,
        "imported": imported_count,
        "duplicates": duplicate_count,
    }