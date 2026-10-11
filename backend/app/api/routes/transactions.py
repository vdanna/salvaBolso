from datetime import date
from decimal import Decimal
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import Account, Transaction, User


router = APIRouter(
    prefix="/transactions",
    tags=["transactions"],
)


def parse_month_range(month: str) -> tuple[date, date]:
    year_text, month_text = month.split("-")
    year = int(year_text)
    month_number = int(month_text)

    start = date(year, month_number, 1)

    if month_number == 12:
        end = date(year + 1, 1, 1)
    else:
        end = date(year, month_number + 1, 1)

    return start, end


def safe_decimal(value: Any) -> Decimal:
    if value is None:
        return Decimal("0")

    if isinstance(value, Decimal):
        return value

    return Decimal(str(value))


def serialize_transaction(
    transaction: Transaction,
    account: Account | None = None,
) -> dict[str, Any]:
    amount = safe_decimal(getattr(transaction, "amount", None))
    amount_abs = getattr(transaction, "amount_abs", None)

    if amount_abs is None:
        amount_abs = abs(amount)

    return {
        "id": transaction.id,
        "user_id": transaction.user_id,
        "account_id": transaction.account_id,
        "account_name": account.name if account else None,
        "institution_name": account.institution_name if account else None,
        "date": transaction.date,
        "amount": amount,
        "amount_abs": safe_decimal(amount_abs),
        "account_type": getattr(transaction, "account_type", None),
        "cash_direction": getattr(transaction, "cash_direction", None),
        "cashflow_type": getattr(transaction, "cashflow_type", None),
        "operation_type": getattr(transaction, "operation_type", None),
        "payment_method": getattr(transaction, "payment_method", None),
        "display_description": getattr(
            transaction,
            "display_description",
            None,
        ),
        "merchant_name": getattr(transaction, "merchant_name", None),
        "category_id": getattr(transaction, "category_id", None),
        "category_name": getattr(transaction, "category_name", None),
        "statement_id": getattr(transaction, "statement_id", None),
        "installment_number": getattr(
            transaction,
            "installment_number",
            None,
        ),
        "installment_total": getattr(
            transaction,
            "installment_total",
            None,
        ),
        "installment_group_key": getattr(
            transaction,
            "installment_group_key",
            None,
        ),
        "reconciliation_status": getattr(
            transaction,
            "reconciliation_status",
            None,
        ),
        "is_reconciled": getattr(transaction, "is_reconciled", False),
        "matched_transaction_id": getattr(
            transaction,
            "matched_transaction_id",
            None,
        ),
        "created_at": getattr(transaction, "created_at", None),
    }


@router.get("")
def list_transactions_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    month: str | None = Query(
        default=None,
        description="Mês no formato YYYY-MM. Use vazio ou all para todos.",
    ),
    account_type: str | None = Query(
        default=None,
        description="checking ou credit_card.",
    ),
    cashflow_type: str | None = Query(
        default=None,
        description="income, expense, debt_payment, liability_increase.",
    ),
    operation_type: str | None = Query(default=None),
    search: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    query = (
        db.query(Transaction, Account)
        .outerjoin(Account, Account.id == Transaction.account_id)
        .filter(Transaction.user_id == current_user.id)
    )

    if month and month != "all":
        start, end = parse_month_range(month)

        query = query.filter(
            Transaction.date >= start,
            Transaction.date < end,
        )

    if account_type and account_type != "all":
        query = query.filter(Transaction.account_type == account_type)

    if cashflow_type and cashflow_type != "all":
        query = query.filter(Transaction.cashflow_type == cashflow_type)

    if operation_type and operation_type != "all":
        query = query.filter(Transaction.operation_type == operation_type)

    if search:
        search_like = f"%{search.strip()}%"

        query = query.filter(
            or_(
                Transaction.display_description.ilike(search_like),
                Transaction.merchant_name.ilike(search_like),
            )
        )

    total = query.count()

    rows = (
        query.order_by(
            Transaction.date.desc(),
            Transaction.id.desc(),
        )
        .offset(offset)
        .limit(limit)
        .all()
    )

    return {
        "items": [
            serialize_transaction(transaction, account)
            for transaction, account in rows
        ],
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_more": offset + limit < total,
    }


@router.get("/{transaction_id}")
def get_transaction_endpoint(
    transaction_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, Any]:
    row = (
        db.query(Transaction, Account)
        .outerjoin(Account, Account.id == Transaction.account_id)
        .filter(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id,
        )
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transação não encontrada.",
        )

    transaction, account = row

    return serialize_transaction(transaction, account)