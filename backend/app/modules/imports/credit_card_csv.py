import csv
import hashlib
import io
import re
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import CreditCardStatement, ImportBatch, Transaction
from app.modules.imports.account_csv import (
    calculate_file_hash,
    detect_csv_encoding,
    normalize_description_for_hash,
    normalize_text,
)

from app.modules.categories.service import (
    bootstrap_default_rules,
    categorize_transaction,
)


NUBANK_CREDIT_CARD_SOURCE_FORMAT = "nubank_credit_card_statement_v1"
EXPECTED_HEADERS = {"date", "title", "amount"}


@dataclass
class ProcessedCreditCardCsv:
    file_name: str
    file_hash: str
    source_format: str
    period_start: date | None
    period_end: date | None
    due_date: date | None
    statement_reference: str | None
    statement_name: str | None

    total_rows: int
    valid_rows: int
    error_rows: int

    charges_total: Decimal
    payments_total: Decimal
    statement_balance: Decimal

    purchase_rows: int
    payment_rows: int
    installment_rows: int
    installment_total: Decimal
    single_purchase_rows: int
    single_purchase_total: Decimal

    transactions: list[dict[str, Any]]
    errors: list[str]
    warnings: list[str]


def read_credit_card_csv_rows(content: bytes) -> list[dict[str, str]]:
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

    headers = {
        header.strip().lower()
        for header in reader.fieldnames
        if header is not None
    }

    if not EXPECTED_HEADERS.issubset(headers):
        raise ValueError(
            "Formato de CSV inválido. Esperado: date, title, amount."
        )

    rows: list[dict[str, str]] = []

    for row in reader:
        if not row:
            continue

        cleaned_row = {
            str(key).strip().lower(): str(value).strip()
            for key, value in row.items()
            if key is not None and value is not None
        }

        if any(cleaned_row.values()):
            rows.append(cleaned_row)

    return rows


def parse_credit_card_amount(value: str) -> Decimal:
    cleaned = value.strip()
    cleaned = cleaned.replace("R$", "")
    cleaned = cleaned.replace(" ", "")

    # Exemplo Nubank cartão:
    # "39,54"       -> 39.54
    # "- 1.830,26"  -> -1830.26
    if "," in cleaned and "." in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    elif "," in cleaned:
        cleaned = cleaned.replace(",", ".")

    try:
        return Decimal(cleaned)
    except InvalidOperation as error:
        raise ValueError(f"Valor inválido: {value}") from error


def parse_nubank_credit_card_date(value: str) -> date:
    try:
        return datetime.strptime(value.strip(), "%Y-%m-%d").date()
    except ValueError as error:
        raise ValueError(f"Data inválida: {value}") from error


def infer_due_date_from_file_name(file_name: str) -> date | None:
    # Exemplo: Nubank_2026-05-23.csv
    match = re.search(r"(\d{4})-(\d{2})-(\d{2})", file_name)

    if not match:
        return None

    year, month, day = match.groups()

    try:
        return date(int(year), int(month), int(day))
    except ValueError:
        return None


def infer_statement_reference(due_date: date | None, period_end: date | None) -> str | None:
    if due_date is not None:
        return due_date.strftime("%Y-%m")

    if period_end is not None:
        return period_end.strftime("%Y-%m")

    return None


def parse_installment_info(title: str) -> tuple[str, int | None, int | None]:
    # Exemplo:
    # Shopee *Gotechssd - Parcela 4/10
    pattern = re.compile(
        r"\s*-\s*Parcela\s+(\d+)\s*/\s*(\d+)\s*$",
        flags=re.IGNORECASE,
    )

    match = pattern.search(title)

    if not match:
        return title.strip(), None, None

    installment_number = int(match.group(1))
    installment_total = int(match.group(2))
    merchant_name = pattern.sub("", title).strip()

    return merchant_name, installment_number, installment_total


def clean_nupay_title(title: str) -> tuple[str, bool]:
    normalized = normalize_text(title)

    if "nupay" not in normalized:
        return title.strip(), False

    cleaned = re.sub(
        r"\s*-\s*NuPay\s*$",
        "",
        title,
        flags=re.IGNORECASE,
    ).strip()

    return cleaned or title.strip(), True


def parse_nubank_credit_card_title(title: str, amount: Decimal) -> dict[str, Any]:
    raw = title.strip()
    normalized = normalize_text(raw)

    parsed: dict[str, Any] = {
        "operation_type": "credit_card_purchase",
        "payment_method": "credit_card",
        "description": "Compra no cartão",
        "display_description": f"Cartão - {raw}",
        "merchant_name": raw,
        "installment_number": None,
        "installment_total": None,
        "installment_group_key": None,
        "is_card_payment": False,
    }

    if normalized == "pagamento recebido":
        return {
            "operation_type": "credit_card_payment_received",
            "payment_method": "credit_card_bill",
            "description": "Pagamento recebido",
            "display_description": "Pagamento recebido na fatura",
            "merchant_name": None,
            "installment_number": None,
            "installment_total": None,
            "installment_group_key": None,
            "is_card_payment": True,
        }

    merchant_name, is_nupay = clean_nupay_title(raw)
    merchant_name, installment_number, installment_total = parse_installment_info(
        merchant_name
    )

    operation_type = (
        "credit_card_installment"
        if installment_number is not None and installment_total is not None
        else "credit_card_purchase"
    )

    payment_method = "nupay" if is_nupay else "credit_card"

    display_description = f"Cartão - {merchant_name}"

    if installment_number is not None and installment_total is not None:
        display_description = (
            f"Cartão - {merchant_name} - Parcela "
            f"{installment_number}/{installment_total}"
        )

    parsed.update(
        {
            "operation_type": operation_type,
            "payment_method": payment_method,
            "description": (
                "Compra parcelada no cartão"
                if operation_type == "credit_card_installment"
                else "Compra no cartão"
            ),
            "display_description": display_description,
            "merchant_name": merchant_name,
            "installment_number": installment_number,
            "installment_total": installment_total,
            "is_card_payment": False,
        }
    )

    return parsed


def classify_credit_card_liability_direction(amount: Decimal) -> str:
    if amount > 0:
        return "increase"

    if amount < 0:
        return "decrease"

    return "none"


def classify_credit_card_cashflow_type(amount: Decimal, operation_type: str) -> str:
    if operation_type in {"credit_card_purchase", "credit_card_installment"}:
        return "expense"

    if operation_type == "credit_card_payment_received":
        return "liability_decrease"

    if amount < 0:
        return "liability_decrease"

    if amount > 0:
        return "expense"

    return "unknown"


def build_installment_group_key(
    account_id: int,
    merchant_name: str | None,
    amount: Decimal,
    installment_total: int | None,
) -> str | None:
    if not merchant_name or installment_total is None:
        return None

    base = "|".join(
        [
            str(account_id),
            normalize_description_for_hash(merchant_name),
            str(abs(amount)),
            str(installment_total),
        ]
    )

    return hashlib.sha256(base.encode("utf-8")).hexdigest()


def normalize_nubank_credit_card_row(
    raw_row: dict[str, str],
    account_id: int,
    row_index: int,
) -> dict[str, Any]:
    transaction_date = parse_nubank_credit_card_date(raw_row["date"])
    amount = parse_credit_card_amount(raw_row["amount"])
    raw_title = raw_row["title"].strip()

    parsed_title = parse_nubank_credit_card_title(
        title=raw_title,
        amount=amount,
    )

    operation_type = parsed_title["operation_type"]
    cashflow_type = classify_credit_card_cashflow_type(
        amount=amount,
        operation_type=operation_type,
    )

    liability_direction = classify_credit_card_liability_direction(amount)

    installment_group_key = build_installment_group_key(
        account_id=account_id,
        merchant_name=parsed_title["merchant_name"],
        amount=amount,
        installment_total=parsed_title["installment_total"],
    )

    return {
        "date": transaction_date,
        "amount": amount,
        "amount_abs": abs(amount),
        "account_type": "credit_card",
        "source": "csv",
        "source_format": NUBANK_CREDIT_CARD_SOURCE_FORMAT,
        "description": parsed_title["description"],
        "display_description": parsed_title["display_description"],
        "raw_description": raw_title,
        "cash_direction": "none",
        "liability_direction": liability_direction,
        "cashflow_type": cashflow_type,
        "operation_type": operation_type,
        "payment_method": parsed_title["payment_method"],
        "merchant_name": parsed_title["merchant_name"],
        "counterparty_name": None,
        "counterparty_document": None,
        "counterparty_institution": None,
        "counterparty_bank_code": None,
        "counterparty_agency": None,
        "counterparty_account": None,
        "external_id": None,
        "billing_cycle_id": None,
        "installment_number": parsed_title["installment_number"],
        "installment_total": parsed_title["installment_total"],
        "installment_group_key": installment_group_key,
        "is_card_payment": parsed_title["is_card_payment"],
        "is_reconciled": False,
        "reconciliation_status": "pending",
        "is_internal_transfer": False,
        "related_external_id": None,
        "metadata_json": {
            "row_index": row_index,
        },
    }


def generate_credit_card_transaction_fingerprint(
    transaction: dict[str, Any],
    account_id: int,
    statement_id: int,
    row_index: int,
) -> str:
    raw_description = normalize_description_for_hash(
        transaction.get("raw_description")
    )

    base = "|".join(
        [
            str(account_id),
            str(statement_id),
            str(transaction["date"]),
            str(transaction["amount"]),
            raw_description,
            str(row_index),
        ]
    )

    return hashlib.sha256(base.encode("utf-8")).hexdigest()


def process_credit_card_csv(
    file_name: str,
    content: bytes,
    account_id: int,
) -> ProcessedCreditCardCsv:
    file_hash = calculate_file_hash(content)
    rows = read_credit_card_csv_rows(content)

    transactions: list[dict[str, Any]] = []
    errors: list[str] = []
    warnings: list[str] = []

    for index, row in enumerate(rows, start=1):
        try:
            transaction = normalize_nubank_credit_card_row(
                raw_row=row,
                account_id=account_id,
                row_index=index,
            )
            transactions.append(transaction)
        except (KeyError, ValueError) as error:
            errors.append(f"Linha {index}: {error}")

    dates = [transaction["date"] for transaction in transactions]

    period_start = min(dates) if dates else None
    period_end = max(dates) if dates else None
    due_date = infer_due_date_from_file_name(file_name)
    statement_reference = infer_statement_reference(
        due_date=due_date,
        period_end=period_end,
    )

    statement_name = (
        f"Fatura Nubank - {statement_reference}"
        if statement_reference is not None
        else "Fatura Nubank"
    )

    charges_total = sum(
        transaction["amount"]
        for transaction in transactions
        if transaction["amount"] > 0
    )

    payments_total = sum(
        transaction["amount_abs"]
        for transaction in transactions
        if transaction["amount"] < 0
    )

    statement_balance = sum(
        transaction["amount"]
        for transaction in transactions
    )

    purchase_rows = sum(
        1
        for transaction in transactions
        if transaction["operation_type"]
        in {"credit_card_purchase", "credit_card_installment"}
    )

    payment_rows = sum(
        1
        for transaction in transactions
        if transaction["operation_type"] == "credit_card_payment_received"
    )

    installment_rows = sum(
        1
        for transaction in transactions
        if transaction["operation_type"] == "credit_card_installment"
    )

    installment_total = sum(
        transaction["amount_abs"]
        for transaction in transactions
        if transaction["operation_type"] == "credit_card_installment"
    )

    single_purchase_rows = sum(
        1
        for transaction in transactions
        if transaction["operation_type"] == "credit_card_purchase"
    )

    single_purchase_total = sum(
        transaction["amount_abs"]
        for transaction in transactions
        if transaction["operation_type"] == "credit_card_purchase"
    )

    if payment_rows > 1:
        warnings.append(
            "O arquivo possui mais de um pagamento recebido. A conciliação será tratada na Fase 7."
        )

    if period_start and period_end and period_start.strftime("%Y-%m") != period_end.strftime("%Y-%m"):
        warnings.append(
            "As compras da fatura pertencem a mais de um mês de consumo. Não confunda mês da compra com mês do pagamento."
        )

    return ProcessedCreditCardCsv(
        file_name=file_name,
        file_hash=file_hash,
        source_format=NUBANK_CREDIT_CARD_SOURCE_FORMAT,
        period_start=period_start,
        period_end=period_end,
        due_date=due_date,
        statement_reference=statement_reference,
        statement_name=statement_name,
        total_rows=len(rows),
        valid_rows=len(transactions),
        error_rows=len(errors),
        charges_total=charges_total,
        payments_total=payments_total,
        statement_balance=statement_balance,
        purchase_rows=purchase_rows,
        payment_rows=payment_rows,
        installment_rows=installment_rows,
        installment_total=installment_total,
        single_purchase_rows=single_purchase_rows,
        single_purchase_total=single_purchase_total,
        transactions=transactions,
        errors=errors,
        warnings=warnings,
    )


def build_credit_card_preview_summary(
    processed: ProcessedCreditCardCsv,
) -> dict[str, Any]:
    sample_transactions = processed.transactions[:10]

    return {
        "file_name": processed.file_name,
        "format": processed.source_format,
        "period_start": processed.period_start,
        "period_end": processed.period_end,
        "due_date": processed.due_date,
        "statement_reference": processed.statement_reference,
        "statement_name": processed.statement_name,
        "total_rows": processed.total_rows,
        "valid_rows": processed.valid_rows,
        "error_rows": processed.error_rows,
        "charges_total": processed.charges_total,
        "payments_total": processed.payments_total,
        "statement_balance": processed.statement_balance,
        "purchase_rows": processed.purchase_rows,
        "payment_rows": processed.payment_rows,
        "installment_rows": processed.installment_rows,
        "installment_total": processed.installment_total,
        "single_purchase_rows": processed.single_purchase_rows,
        "single_purchase_total": processed.single_purchase_total,
        "warnings": processed.warnings,
        "sample_transactions": [
            {
                "date": transaction["date"],
                "amount": transaction["amount"],
                "liability_direction": transaction["liability_direction"],
                "cashflow_type": transaction["cashflow_type"],
                "operation_type": transaction["operation_type"],
                "payment_method": transaction["payment_method"],
                "merchant_name": transaction["merchant_name"],
                "display_description": transaction["display_description"],
                "raw_description": transaction["raw_description"],
                "installment_number": transaction["installment_number"],
                "installment_total": transaction["installment_total"],
                "is_card_payment": transaction["is_card_payment"],
            }
            for transaction in sample_transactions
        ],
    }


def find_existing_credit_card_statement(
    db: Session,
    user_id: int,
    account_id: int,
    file_hash: str,
) -> CreditCardStatement | None:
    statement = (
        select(CreditCardStatement)
        .where(CreditCardStatement.user_id == user_id)
        .where(CreditCardStatement.account_id == account_id)
        .where(CreditCardStatement.file_hash == file_hash)
    )

    return db.scalar(statement)


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


def create_credit_card_statement(
    db: Session,
    user_id: int,
    account_id: int,
    processed: ProcessedCreditCardCsv,
) -> CreditCardStatement:
    statement = CreditCardStatement(
        user_id=user_id,
        account_id=account_id,
        statement_reference=processed.statement_reference,
        statement_name=processed.statement_name,
        file_name=processed.file_name,
        file_hash=processed.file_hash,
        period_start=processed.period_start,
        period_end=processed.period_end,
        due_date=processed.due_date,
        closing_date=None,
        total_charges=processed.charges_total,
        total_payments=processed.payments_total,
        statement_balance=processed.statement_balance,
        matched_bank_payment_id=None,
        matched_card_payment_id=None,
        reconciliation_status="pending",
    )

    db.add(statement)
    db.flush()

    return statement


def create_import_batch(
    db: Session,
    user_id: int,
    account_id: int,
    processed: ProcessedCreditCardCsv,
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


def save_credit_card_csv_transactions(
    db: Session,
    user_id: int,
    account_id: int,
    processed: ProcessedCreditCardCsv,
) -> dict[str, Any]:
    existing_statement = find_existing_credit_card_statement(
        db=db,
        user_id=user_id,
        account_id=account_id,
        file_hash=processed.file_hash,
    )

    if existing_statement is not None:
        raise ValueError("Este CSV de fatura já foi importado para esta conta.")

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

    credit_card_statement = create_credit_card_statement(
        db=db,
        user_id=user_id,
        account_id=account_id,
        processed=processed,
    )

    transactions_with_fingerprint: list[dict[str, Any]] = []

    for transaction_data in processed.transactions:
        row_index = transaction_data.get("metadata_json", {}).get("row_index", 0)

        transaction_data = {
            **transaction_data,
            "statement_id": credit_card_statement.id,
        }

        transaction_data["fingerprint"] = generate_credit_card_transaction_fingerprint(
            transaction=transaction_data,
            account_id=account_id,
            statement_id=credit_card_statement.id,
            row_index=row_index,
        )

        transactions_with_fingerprint.append(transaction_data)

    fingerprints = [
        transaction["fingerprint"]
        for transaction in transactions_with_fingerprint
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

    for transaction_data in transactions_with_fingerprint:
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
    db.refresh(credit_card_statement)

    return {
        "import_batch": import_batch,
        "statement": credit_card_statement,
        "imported": imported_count,
        "duplicates": duplicate_count,
        "matched_payments": 0,
        "pending_payments": processed.payment_rows,
    }