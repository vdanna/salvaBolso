from collections import defaultdict
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import CreditCardStatement, Transaction


ZERO = Decimal("0.00")


def quantize_money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def quantize_percentage(value: Decimal) -> Decimal:
    return Decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def parse_month(month: str) -> tuple[date, date]:
    try:
        year_text, month_text = month.split("-")
        year = int(year_text)
        month_number = int(month_text)

        start = date(year, month_number, 1)

        if month_number == 12:
            end = date(year + 1, 1, 1)
        else:
            end = date(year, month_number + 1, 1)

        return start, end

    except ValueError as error:
        raise ValueError("Mês inválido. Use o formato YYYY-MM.") from error


def month_key(value: date) -> str:
    return value.strftime("%Y-%m")


def safe_amount_abs(transaction: Transaction) -> Decimal:
    if transaction.amount_abs is not None:
        return Decimal(transaction.amount_abs)

    return abs(Decimal(transaction.amount))


def serialize_transaction(transaction: Transaction) -> dict[str, Any]:
    return {
        "id": transaction.id,
        "date": transaction.date,
        "amount": transaction.amount,
        "amount_abs": safe_amount_abs(transaction),
        "account_type": transaction.account_type,
        "cashflow_type": transaction.cashflow_type,
        "operation_type": transaction.operation_type,
        "payment_method": transaction.payment_method,
        "merchant_name": transaction.merchant_name,
        "display_description": transaction.display_description,
        "is_reconciled": transaction.is_reconciled,
        "reconciliation_status": transaction.reconciliation_status,
    }


def get_transactions_by_month(
    db: Session,
    user_id: int,
    month: str,
) -> tuple[date, date, list[Transaction]]:
    period_start, period_end = parse_month(month)

    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .where(Transaction.date >= period_start)
        .where(Transaction.date < period_end)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    transactions = list(db.scalars(statement).all())

    return period_start, period_end, transactions


def get_cashflow_summary(
    db: Session,
    user_id: int,
    month: str,
) -> dict[str, Any]:
    period_start, period_end, transactions = get_transactions_by_month(
        db=db,
        user_id=user_id,
        month=month,
    )

    checking_transactions = [
        transaction
        for transaction in transactions
        if transaction.account_type == "checking"
    ]

    gross_inflow = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
        if transaction.cash_direction == "inflow"
    )

    gross_outflow = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.cash_direction == "outflow"
    )

    net_cashflow = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
    )

    income = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
        if transaction.cashflow_type == "income"
    )

    expenses = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.cashflow_type == "expense"
    )

    debt_payments = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.cashflow_type == "debt_payment"
    )

    liability_increase = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
        if transaction.cashflow_type == "liability_increase"
    )

    card_bill_payments = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.operation_type == "credit_card_bill_payment"
    )

    reconciled_card_bill_payments = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.operation_type == "credit_card_bill_payment"
        and transaction.is_reconciled
    )

    unreconciled_card_bill_payments = (
        card_bill_payments - reconciled_card_bill_payments
    )

    warnings: list[str] = []

    if unreconciled_card_bill_payments > ZERO:
        warnings.append(
            "Há pagamento de fatura ainda não conciliado com uma fatura de cartão."
        )

    if liability_increase > ZERO:
        warnings.append(
            "Há valor adicionado à conta por cartão de crédito. Isso aumenta caixa, mas também aumenta dívida."
        )

    return {
        "month": month,
        "period_start": period_start,
        "period_end": period_end,
        "transaction_count": len(checking_transactions),
        "gross_inflow": quantize_money(gross_inflow),
        "gross_outflow": quantize_money(gross_outflow),
        "net_cashflow": quantize_money(net_cashflow),
        "income": quantize_money(income),
        "expenses": quantize_money(expenses),
        "debt_payments": quantize_money(debt_payments),
        "liability_increase": quantize_money(liability_increase),
        "card_bill_payments": quantize_money(card_bill_payments),
        "reconciled_card_bill_payments": quantize_money(
            reconciled_card_bill_payments
        ),
        "unreconciled_card_bill_payments": quantize_money(
            unreconciled_card_bill_payments
        ),
        "warnings": warnings,
    }


def get_consumption_summary(
    db: Session,
    user_id: int,
    month: str,
    basis: Literal["purchase_date"] = "purchase_date",
) -> dict[str, Any]:
    if basis != "purchase_date":
        raise ValueError("Por enquanto, a única base suportada é purchase_date.")

    period_start, period_end, transactions = get_transactions_by_month(
        db=db,
        user_id=user_id,
        month=month,
    )

    consumption_transactions = [
        transaction
        for transaction in transactions
        if transaction.cashflow_type == "expense"
    ]

    total_consumption = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
    )

    checking_consumption = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.account_type == "checking"
    )

    credit_card_consumption = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.account_type == "credit_card"
    )

    debit_card_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "debit_card"
    )

    pix_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "pix"
    )

    bank_slip_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "bank_slip"
    )

    credit_card_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "credit_card"
    )

    nupay_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "nupay"
    )

    installment_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.operation_type == "credit_card_installment"
    )

    single_purchase_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.operation_type in {
            "credit_card_purchase",
            "debit_purchase",
            "pix_sent",
            "bank_slip_payment",
        }
    )

    top_transactions = sorted(
        consumption_transactions,
        key=lambda transaction: safe_amount_abs(transaction),
        reverse=True,
    )[:10]

    warnings: list[str] = [
        "Este resumo não soma pagamento de fatura como consumo para evitar dupla contagem."
    ]

    return {
        "month": month,
        "basis": basis,
        "period_start": period_start,
        "period_end": period_end,
        "transaction_count": len(consumption_transactions),
        "total_consumption": quantize_money(total_consumption),
        "checking_consumption": quantize_money(checking_consumption),
        "credit_card_consumption": quantize_money(credit_card_consumption),
        "debit_card_total": quantize_money(debit_card_total),
        "pix_total": quantize_money(pix_total),
        "bank_slip_total": quantize_money(bank_slip_total),
        "credit_card_total": quantize_money(credit_card_total),
        "nupay_total": quantize_money(nupay_total),
        "installment_total": quantize_money(installment_total),
        "single_purchase_total": quantize_money(single_purchase_total),
        "top_transactions": [
            serialize_transaction(transaction)
            for transaction in top_transactions
        ],
        "warnings": warnings,
    }


def get_statement_summary(
    db: Session,
    user_id: int,
    statement_id: int,
) -> dict[str, Any] | None:
    statement_query = (
        select(CreditCardStatement)
        .where(CreditCardStatement.id == statement_id)
        .where(CreditCardStatement.user_id == user_id)
    )

    credit_card_statement = db.scalar(statement_query)

    if credit_card_statement is None:
        return None

    transactions_query = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .where(Transaction.statement_id == statement_id)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    transactions = list(db.scalars(transactions_query).all())

    purchase_transactions = [
        transaction
        for transaction in transactions
        if transaction.cashflow_type == "expense"
    ]

    payment_transactions = [
        transaction
        for transaction in transactions
        if transaction.operation_type == "credit_card_payment_received"
    ]

    installment_transactions = [
        transaction
        for transaction in transactions
        if transaction.operation_type == "credit_card_installment"
    ]

    single_purchase_transactions = [
        transaction
        for transaction in transactions
        if transaction.operation_type == "credit_card_purchase"
    ]

    return {
        "statement_id": credit_card_statement.id,
        "statement_reference": credit_card_statement.statement_reference,
        "statement_name": credit_card_statement.statement_name,
        "file_name": credit_card_statement.file_name,
        "period_start": credit_card_statement.period_start,
        "period_end": credit_card_statement.period_end,
        "due_date": credit_card_statement.due_date,
        "total_charges": credit_card_statement.total_charges,
        "total_payments": credit_card_statement.total_payments,
        "statement_balance": credit_card_statement.statement_balance,
        "reconciliation_status": credit_card_statement.reconciliation_status,
        "transaction_count": len(transactions),
        "purchase_count": len(purchase_transactions),
        "payment_count": len(payment_transactions),
        "installment_count": len(installment_transactions),
        "purchases_total": quantize_money(
            sum(safe_amount_abs(transaction) for transaction in purchase_transactions)
        ),
        "payments_total": quantize_money(
            sum(safe_amount_abs(transaction) for transaction in payment_transactions)
        ),
        "installments_total": quantize_money(
            sum(safe_amount_abs(transaction) for transaction in installment_transactions)
        ),
        "single_purchases_total": quantize_money(
            sum(safe_amount_abs(transaction) for transaction in single_purchase_transactions)
        ),
        "matched_bank_payment_id": credit_card_statement.matched_bank_payment_id,
        "matched_card_payment_id": credit_card_statement.matched_card_payment_id,
        "transactions": [
            serialize_transaction(transaction)
            for transaction in transactions
        ],
    }


def get_categories_summary(
    db: Session,
    user_id: int,
    month: str,
    view: Literal["consumption", "cashflow"] = "consumption",
) -> dict[str, Any]:
    _, _, transactions = get_transactions_by_month(
        db=db,
        user_id=user_id,
        month=month,
    )

    if view == "consumption":
        relevant_transactions = [
            transaction
            for transaction in transactions
            if transaction.cashflow_type == "expense"
        ]
    elif view == "cashflow":
        relevant_transactions = [
            transaction
            for transaction in transactions
            if transaction.account_type == "checking"
            and transaction.cash_direction == "outflow"
        ]
    else:
        raise ValueError("View inválida. Use consumption ou cashflow.")

    grouped: dict[int | None, dict[str, Any]] = defaultdict(
        lambda: {
            "total": ZERO,
            "transaction_count": 0,
        }
    )

    for transaction in relevant_transactions:
        category_id = transaction.category_id
        grouped[category_id]["total"] += safe_amount_abs(transaction)
        grouped[category_id]["transaction_count"] += 1

    total = sum(item["total"] for item in grouped.values())

    items = []

    for category_id, item in grouped.items():
        if total > ZERO:
            percentage = (item["total"] / total) * Decimal("100")
        else:
            percentage = ZERO

        if category_id is None:
            category_name = "Sem categoria"
        else:
            category_name = f"Categoria {category_id}"

        items.append(
            {
                "category_id": category_id,
                "category_name": category_name,
                "total": quantize_money(item["total"]),
                "transaction_count": item["transaction_count"],
                "percentage": quantize_percentage(percentage),
            }
        )

    items.sort(key=lambda item: item["total"], reverse=True)

    return {
        "month": month,
        "view": view,
        "total": quantize_money(total),
        "items": items,
    }


def get_credit_card_merchants_summary(
    db: Session,
    user_id: int,
    month: str,
) -> dict[str, Any]:
    _, _, transactions = get_transactions_by_month(
        db=db,
        user_id=user_id,
        month=month,
    )

    card_expenses = [
        transaction
        for transaction in transactions
        if transaction.account_type == "credit_card"
        and transaction.cashflow_type == "expense"
    ]

    grouped: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "total": ZERO,
            "transaction_count": 0,
        }
    )

    for transaction in card_expenses:
        merchant_name = (
            transaction.merchant_name
            or transaction.display_description
            or "Não identificado"
        )

        grouped[merchant_name]["total"] += safe_amount_abs(transaction)
        grouped[merchant_name]["transaction_count"] += 1

    total = sum(item["total"] for item in grouped.values())

    items = []

    for merchant_name, item in grouped.items():
        if total > ZERO:
            percentage = (item["total"] / total) * Decimal("100")
        else:
            percentage = ZERO

        items.append(
            {
                "merchant_name": merchant_name,
                "total": quantize_money(item["total"]),
                "transaction_count": item["transaction_count"],
                "percentage": quantize_percentage(percentage),
            }
        )

    items.sort(key=lambda item: item["total"], reverse=True)

    return {
        "month": month,
        "total": quantize_money(total),
        "items": items,
    }


#def get_credit_card_installments_summary(
#    db: Session,
#    user_id: int,
#    month: str,
#) -> dict[str, Any]:
#    _, _, transactions = get_transactions_by_month(
#        db=db,
#        user_id=user_id,
#        month=month,
#    )
#
#    installment_transactions = [
#        transaction
#        for transaction in transactions
#        if transaction.account_type == "credit_card"
#        and transaction.operation_type == "credit_card_installment"
#    ]
#
#    grouped: dict[str, dict[str, Any]] = defaultdict(
#        lambda: {
#            "installment_group_key": None,
#            "merchant_name": "Não identificado",
#            "installment_total": None,
#            "amount_in_month": ZERO,
#            "transaction_count_in_month": 0,
#            "installments_seen": set(),
#        }
#    )
#
#    for transaction in installment_transactions:
#        key = (
#            transaction.installment_group_key
#            or f"{transaction.merchant_name}-{transaction.amount_abs}-{transaction.installment_total}"
#        )
#
#        grouped[key]["installment_group_key"] = transaction.installment_group_key
#        grouped[key]["merchant_name"] = (
#            transaction.merchant_name
#            or transaction.display_description
#            or "Não identificado"
#        )
#        grouped[key]["installment_total"] = transaction.installment_total
#        grouped[key]["amount_in_month"] += safe_amount_abs(transaction)
#        grouped[key]["transaction_count_in_month"] += 1
#
#        if transaction.installment_number is not None:
#            grouped[key]["installments_seen"].add(transaction.installment_number)
#
#    items = []
#
#    for item in grouped.values():
#        items.append(
#            {
#                "installment_group_key": item["installment_group_key"],
#                "merchant_name": item["merchant_name"],
#                "installment_total": item["installment_total"],
#                "amount_in_month": quantize_money(item["amount_in_month"]),
#                "transaction_count_in_month": item["transaction_count_in_month"],
#                "installments_seen": sorted(item["installments_seen"]),
#            }
#        )
#
#    items.sort(key=lambda item: item["amount_in_month"], reverse=True)
#
#    total_installments_in_month = sum(
#        item["amount_in_month"]
#        for item in grouped.values()
#    )
#
#    return {
#        "month": month,
#        "total_installments_in_month": quantize_money(
#            total_installments_in_month
#        ),
#        "items": items,
#    }

def get_credit_card_installments_summary(
    db: Session,
    user_id: int,
    month: str,
) -> dict[str, Any]:
    statement = (
        select(Transaction)
        .join(
            CreditCardStatement,
            CreditCardStatement.id == Transaction.statement_id,
        )
        .where(
            Transaction.user_id == user_id,
            Transaction.account_type == "credit_card",
            Transaction.operation_type == "credit_card_installment",
            CreditCardStatement.statement_reference == month,
        )
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    transactions = list(db.scalars(statement).all())

    grouped_installments: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "installment_group_key": None,
            "merchant_name": "Não identificado",
            "installment_total": None,
            "amount_in_month": ZERO,
            "transaction_count_in_month": 0,
            "installments_seen": set(),
        }
    )

    for transaction in transactions:
        key = (
            transaction.installment_group_key
            or f"{transaction.merchant_name}-{transaction.amount_abs}-{transaction.installment_total}"
        )

        grouped_installments[key]["installment_group_key"] = (
            transaction.installment_group_key
        )
        grouped_installments[key]["merchant_name"] = (
            transaction.merchant_name
            or transaction.display_description
            or "Não identificado"
        )
        grouped_installments[key]["installment_total"] = (
            transaction.installment_total
        )
        grouped_installments[key]["amount_in_month"] += safe_amount_abs(
            transaction
        )
        grouped_installments[key]["transaction_count_in_month"] += 1

        if transaction.installment_number is not None:
            grouped_installments[key]["installments_seen"].add(
                transaction.installment_number
            )

    items = []

    for item in grouped_installments.values():
        items.append(
            {
                "installment_group_key": item["installment_group_key"],
                "merchant_name": item["merchant_name"],
                "installment_total": item["installment_total"],
                "amount_in_month": quantize_money(item["amount_in_month"]),
                "transaction_count_in_month": item[
                    "transaction_count_in_month"
                ],
                "installments_seen": sorted(item["installments_seen"]),
            }
        )

    items.sort(
        key=lambda item: item["amount_in_month"],
        reverse=True,
    )

    total_installments_in_month = sum(
        item["amount_in_month"]
        for item in grouped_installments.values()
    )

    return {
        "month": month,
        "basis": "statement_reference",
        "total_installments_in_month": quantize_money(
            total_installments_in_month
        ),
        "items": items,
        "warnings": [
            "As compras parceladas são listadas pelo mês da fatura, não pela data original da compra."
        ],
    }


def get_recurring_expenses(
    db: Session,
    user_id: int,
    months_back: int = 6,
    minimum_occurrences: int = 2,
) -> dict[str, Any]:
    if months_back < 2 or months_back > 24:
        raise ValueError("months_back precisa estar entre 2 e 24.")

    if minimum_occurrences < 2:
        raise ValueError("minimum_occurrences precisa ser pelo menos 2.")

    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .where(Transaction.cashflow_type == "expense")
        .order_by(Transaction.date.desc(), Transaction.id.desc())
    )

    all_expense_transactions = list(db.scalars(statement).all())

    months_available = sorted(
        {month_key(transaction.date) for transaction in all_expense_transactions},
        reverse=True,
    )[:months_back]

    allowed_months = set(months_available)

    transactions = [
        transaction
        for transaction in all_expense_transactions
        if month_key(transaction.date) in allowed_months
    ]

    grouped: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "description": "",
            "merchant_name": None,
            "payment_method": "",
            "amounts": [],
            "months_seen": set(),
        }
    )

    for transaction in transactions:
        description = (
            transaction.merchant_name
            or transaction.display_description
            or transaction.raw_description
            or "Não identificado"
        )

        key = f"{description.lower()}|{transaction.payment_method}"

        grouped[key]["description"] = description
        grouped[key]["merchant_name"] = transaction.merchant_name
        grouped[key]["payment_method"] = transaction.payment_method
        grouped[key]["amounts"].append(safe_amount_abs(transaction))
        grouped[key]["months_seen"].add(month_key(transaction.date))

    items = []

    for item in grouped.values():
        occurrences = len(item["amounts"])
        months_seen = sorted(item["months_seen"])

        if occurrences < minimum_occurrences:
            continue

        if len(months_seen) < minimum_occurrences:
            continue

        average_amount = sum(item["amounts"]) / Decimal(occurrences)
        last_amount = item["amounts"][0]

        items.append(
            {
                "description": item["description"],
                "merchant_name": item["merchant_name"],
                "payment_method": item["payment_method"],
                "average_amount": quantize_money(average_amount),
                "last_amount": quantize_money(last_amount),
                "occurrences": occurrences,
                "months_seen": months_seen,
            }
        )

    items.sort(key=lambda item: item["average_amount"], reverse=True)

    return {
        "months_back": months_back,
        "minimum_occurrences": minimum_occurrences,
        "items": items,
    }


def get_health_score(
    db: Session,
    user_id: int,
    month: str,
) -> dict[str, Any]:
    cashflow = get_cashflow_summary(
        db=db,
        user_id=user_id,
        month=month,
    )

    consumption = get_consumption_summary(
        db=db,
        user_id=user_id,
        month=month,
    )

    income = Decimal(cashflow["income"])
    total_consumption = Decimal(consumption["total_consumption"])
    debt_payments = Decimal(cashflow["debt_payments"])
    net_cashflow = Decimal(cashflow["net_cashflow"])

    score = 100
    warnings: list[str] = []
    recommendations: list[str] = []

    if income <= ZERO:
        score -= 40
        warnings.append("Não há renda identificada neste mês.")
        recommendations.append(
            "Revise as entradas do mês para confirmar se foram classificadas como renda."
        )

        consumption_rate = None
        debt_payment_rate = None
        cash_margin_rate = None
    else:
        consumption_rate = (total_consumption / income) * Decimal("100")
        debt_payment_rate = (debt_payments / income) * Decimal("100")
        cash_margin_rate = (net_cashflow / income) * Decimal("100")

        if consumption_rate > Decimal("80"):
            score -= 20
            warnings.append("O consumo passou de 80% da renda identificada.")
            recommendations.append(
                "Revise os maiores gastos do mês e separe o que foi essencial do que foi impulso."
            )

        if debt_payment_rate > Decimal("30"):
            score -= 20
            warnings.append("Pagamentos de dívida/fatura passaram de 30% da renda.")
            recommendations.append(
                "Acompanhe a fatura do cartão para evitar que compras antigas comprimam o caixa."
            )

        if cash_margin_rate < ZERO:
            score -= 25
            warnings.append("O fluxo de caixa do mês ficou negativo.")
            recommendations.append(
                "Evite assumir novos gastos parcelados antes de recuperar margem de caixa."
            )

        elif cash_margin_rate < Decimal("10"):
            score -= 10
            warnings.append("A margem de caixa ficou abaixo de 10% da renda.")
            recommendations.append(
                "Tente reservar uma pequena margem antes de aumentar consumo variável."
            )

    if Decimal(cashflow["unreconciled_card_bill_payments"]) > ZERO:
        score -= 10
        warnings.append("Há pagamento de fatura ainda não conciliado.")
        recommendations.append(
            "Finalize a conciliação para melhorar a precisão dos resumos."
        )

    if score < 0:
        score = 0

    if score >= 80:
        status = "bom"
    elif score >= 60:
        status = "atenção"
    else:
        status = "crítico"

    return {
        "month": month,
        "score": score,
        "status": status,
        "income": quantize_money(income),
        "consumption": quantize_money(total_consumption),
        "debt_payments": quantize_money(debt_payments),
        "net_cashflow": quantize_money(net_cashflow),
        "consumption_rate": (
            quantize_percentage(consumption_rate)
            if consumption_rate is not None
            else None
        ),
        "debt_payment_rate": (
            quantize_percentage(debt_payment_rate)
            if debt_payment_rate is not None
            else None
        ),
        "cash_margin_rate": (
            quantize_percentage(cash_margin_rate)
            if cash_margin_rate is not None
            else None
        ),
        "warnings": warnings,
        "recommendations": recommendations,
    }

def get_available_transaction_months(
    db: Session,
    user_id: int,
) -> list[str]:
    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .order_by(Transaction.date.desc(), Transaction.id.desc())
    )

    transactions = list(db.scalars(statement).all())

    return sorted(
        {month_key(transaction.date) for transaction in transactions},
        reverse=True,
    )


def get_overall_dashboard_summary(
    db: Session,
    user_id: int,
) -> dict[str, Any]:
    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    transactions = list(db.scalars(statement).all())

    months = sorted(
        {month_key(transaction.date) for transaction in transactions},
        reverse=True,
    )

    checking_transactions = [
        transaction
        for transaction in transactions
        if transaction.account_type == "checking"
    ]

    gross_inflow = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
        if transaction.cash_direction == "inflow"
    )

    gross_outflow = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.cash_direction == "outflow"
    )

    net_cashflow = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
    )

    income = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
        if transaction.cashflow_type == "income"
    )

    expenses = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.cashflow_type == "expense"
    )

    debt_payments = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.cashflow_type == "debt_payment"
    )

    liability_increase = sum(
        Decimal(transaction.amount)
        for transaction in checking_transactions
        if transaction.cashflow_type == "liability_increase"
    )

    card_bill_payments = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.operation_type == "credit_card_bill_payment"
    )

    reconciled_card_bill_payments = sum(
        safe_amount_abs(transaction)
        for transaction in checking_transactions
        if transaction.operation_type == "credit_card_bill_payment"
        and transaction.is_reconciled
    )

    unreconciled_card_bill_payments = (
        card_bill_payments - reconciled_card_bill_payments
    )

    consumption_transactions = [
        transaction
        for transaction in transactions
        if transaction.cashflow_type == "expense"
    ]

    grouped_categories: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "total": ZERO,
            "transaction_count": 0,
        }
    )

    for transaction in consumption_transactions:
        category_name = getattr(transaction, "category_name", None)

        if not category_name:
            category_name = "Sem categoria"

        grouped_categories[category_name]["total"] += safe_amount_abs(
            transaction
        )
        grouped_categories[category_name]["transaction_count"] += 1

    categories_total = sum(
        item["total"]
        for item in grouped_categories.values()
    )

    categories_items = []

    for category_name, item in grouped_categories.items():
        if categories_total > ZERO:
            percentage = (item["total"] / categories_total) * Decimal("100")
        else:
            percentage = ZERO

        categories_items.append(
            {
                "category_name": category_name,
                "total": quantize_money(item["total"]),
                "transaction_count": item["transaction_count"],
                "percentage": quantize_percentage(percentage),
            }
        )

    categories_items.sort(
        key=lambda item: item["total"],
        reverse=True,
    )

    total_consumption = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
    )

    checking_consumption = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.account_type == "checking"
    )

    credit_card_consumption = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.account_type == "credit_card"
    )

    debit_card_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "debit_card"
    )

    pix_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "pix"
    )

    bank_slip_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "bank_slip"
    )

    credit_card_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "credit_card"
    )

    nupay_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.payment_method == "nupay"
    )

    installment_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.operation_type == "credit_card_installment"
    )

    single_purchase_total = sum(
        safe_amount_abs(transaction)
        for transaction in consumption_transactions
        if transaction.operation_type in {
            "credit_card_purchase",
            "debit_purchase",
            "pix_sent",
            "bank_slip_payment",
        }
    )

    top_transactions = sorted(
        consumption_transactions,
        key=lambda transaction: safe_amount_abs(transaction),
        reverse=True,
    )[:10]

    card_expenses = [
        transaction
        for transaction in transactions
        if transaction.account_type == "credit_card"
        and transaction.cashflow_type == "expense"
    ]

    grouped_merchants: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "total": ZERO,
            "transaction_count": 0,
        }
    )

    for transaction in card_expenses:
        merchant_name = (
            transaction.merchant_name
            or transaction.display_description
            or "Não identificado"
        )

        grouped_merchants[merchant_name]["total"] += safe_amount_abs(transaction)
        grouped_merchants[merchant_name]["transaction_count"] += 1

    merchants_total = sum(
        item["total"]
        for item in grouped_merchants.values()
    )

    merchants_items = []

    for merchant_name, item in grouped_merchants.items():
        if merchants_total > ZERO:
            percentage = (item["total"] / merchants_total) * Decimal("100")
        else:
            percentage = ZERO

        merchants_items.append(
            {
                "merchant_name": merchant_name,
                "total": quantize_money(item["total"]),
                "transaction_count": item["transaction_count"],
                "percentage": quantize_percentage(percentage),
            }
        )

    merchants_items.sort(key=lambda item: item["total"], reverse=True)

    installment_transactions = [
        transaction
        for transaction in transactions
        if transaction.account_type == "credit_card"
        and transaction.operation_type == "credit_card_installment"
    ]

    grouped_installments: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "installment_group_key": None,
            "merchant_name": "Não identificado",
            "installment_total": None,
            "amount_in_month": ZERO,
            "transaction_count_in_month": 0,
            "installments_seen": set(),
        }
    )

    for transaction in installment_transactions:
        key = (
            transaction.installment_group_key
            or f"{transaction.merchant_name}-{transaction.amount_abs}-{transaction.installment_total}"
        )

        grouped_installments[key]["installment_group_key"] = (
            transaction.installment_group_key
        )
        grouped_installments[key]["merchant_name"] = (
            transaction.merchant_name
            or transaction.display_description
            or "Não identificado"
        )
        grouped_installments[key]["installment_total"] = (
            transaction.installment_total
        )
        grouped_installments[key]["amount_in_month"] += safe_amount_abs(
            transaction
        )
        grouped_installments[key]["transaction_count_in_month"] += 1

        if transaction.installment_number is not None:
            grouped_installments[key]["installments_seen"].add(
                transaction.installment_number
            )

    installment_items = []

    for item in grouped_installments.values():
        installment_items.append(
            {
                "installment_group_key": item["installment_group_key"],
                "merchant_name": item["merchant_name"],
                "installment_total": item["installment_total"],
                "amount_in_month": quantize_money(item["amount_in_month"]),
                "transaction_count_in_month": item["transaction_count_in_month"],
                "installments_seen": sorted(item["installments_seen"]),
            }
        )

    installment_items.sort(
        key=lambda item: item["amount_in_month"],
        reverse=True,
    )

    warnings: list[str] = [
        "Este resumo geral consolida todos os meses importados."
    ]

    if unreconciled_card_bill_payments > ZERO:
        warnings.append(
            "Há pagamentos de fatura ainda não conciliados."
        )

    if liability_increase > ZERO:
        warnings.append(
            "Há valor adicionado à conta por cartão de crédito. Isso aumenta caixa, mas também aumenta dívida."
        )

    score = 100
    recommendations: list[str] = []

    if income <= ZERO:
        score -= 40
        consumption_rate = None
        debt_payment_rate = None
        cash_margin_rate = None
        warnings.append("Não há renda identificada no período geral.")
        recommendations.append(
            "Revise as entradas para confirmar se foram classificadas como renda."
        )
    else:
        consumption_rate = quantize_percentage(
            (total_consumption / income) * Decimal("100")
        )
        debt_payment_rate = quantize_percentage(
            (debt_payments / income) * Decimal("100")
        )
        cash_margin_rate = quantize_percentage(
            (net_cashflow / income) * Decimal("100")
        )

        if consumption_rate > Decimal("80"):
            score -= 20
            warnings.append(
                "O consumo geral passou de 80% da renda identificada."
            )

        if debt_payment_rate > Decimal("30"):
            score -= 20
            warnings.append(
                "Pagamentos de dívida/fatura estão altos em relação à renda."
            )

        if cash_margin_rate < Decimal("10"):
            score -= 15
            warnings.append(
                "A margem geral de caixa está baixa."
            )

    score = max(score, 0)

    if score >= 80:
        status_text = "saudável"
    elif score >= 60:
        status_text = "atenção"
    else:
        status_text = "crítico"

    return {
        "months": months,
        "cashflow": {
            "month": "all",
            "period_start": None,
            "period_end": None,
            "transaction_count": len(checking_transactions),
            "gross_inflow": quantize_money(gross_inflow),
            "gross_outflow": quantize_money(gross_outflow),
            "net_cashflow": quantize_money(net_cashflow),
            "income": quantize_money(income),
            "expenses": quantize_money(expenses),
            "debt_payments": quantize_money(debt_payments),
            "liability_increase": quantize_money(liability_increase),
            "card_bill_payments": quantize_money(card_bill_payments),
            "reconciled_card_bill_payments": quantize_money(
                reconciled_card_bill_payments
            ),
            "unreconciled_card_bill_payments": quantize_money(
                unreconciled_card_bill_payments
            ),
            "warnings": warnings,
        },
        "consumption": {
            "month": "all",
            "basis": "purchase_date",
            "period_start": None,
            "period_end": None,
            "transaction_count": len(consumption_transactions),
            "total_consumption": quantize_money(total_consumption),
            "checking_consumption": quantize_money(checking_consumption),
            "credit_card_consumption": quantize_money(credit_card_consumption),
            "debit_card_total": quantize_money(debit_card_total),
            "pix_total": quantize_money(pix_total),
            "bank_slip_total": quantize_money(bank_slip_total),
            "credit_card_total": quantize_money(credit_card_total),
            "nupay_total": quantize_money(nupay_total),
            "installment_total": quantize_money(installment_total),
            "single_purchase_total": quantize_money(single_purchase_total),
            "top_transactions": [
                serialize_transaction(transaction)
                for transaction in top_transactions
            ],
            "warnings": [
                "Este resumo não soma pagamento de fatura como consumo para evitar dupla contagem."
            ],
        },
        "health_score": {
            "month": "all",
            "score": score,
            "status": status_text,
            "income": quantize_money(income),
            "consumption": quantize_money(total_consumption),
            "debt_payments": quantize_money(debt_payments),
            "net_cashflow": quantize_money(net_cashflow),
            "consumption_rate": consumption_rate,
            "debt_payment_rate": debt_payment_rate,
            "cash_margin_rate": cash_margin_rate,
            "warnings": warnings,
            "recommendations": recommendations,
        },
        "merchants": {
            "month": "all",
            "total": quantize_money(merchants_total),
            "items": merchants_items,
        },
        "installments": {
            "month": "all",
            "total_installments_in_month": quantize_money(
                sum(
                    item["amount_in_month"]
                    for item in grouped_installments.values()
                )
            ),
            "items": installment_items,
        },
        "categories": {
            "month": "all",
            "view": "consumption",
            "total": quantize_money(categories_total),
            "items": categories_items,
        },
    }