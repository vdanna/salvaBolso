from datetime import date
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import Account, CreditCardStatement, User


router = APIRouter(
    prefix="/credit-card/statements",
    tags=["credit-card-statements"],
)


class CreditCardStatementListItem(BaseModel):
    id: int
    account_id: int
    account_name: str | None = None
    institution_name: str | None = None

    statement_reference: str | None = None
    statement_name: str | None = None

    period_start: date | None = None
    period_end: date | None = None
    due_date: date | None = None
    closing_date: date | None = None

    charges_total: Decimal = Decimal("0")
    payments_total: Decimal = Decimal("0")
    statement_balance: Decimal = Decimal("0")

    reconciliation_status: str


@router.get("", response_model=list[CreditCardStatementListItem])
def list_credit_card_statements_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    month: str | None = Query(
        default=None,
        pattern=r"^\d{4}-\d{2}$",
        description="Mês da fatura no formato YYYY-MM. Exemplo: 2026-05.",
    ),
) -> list[CreditCardStatementListItem]:
    query = (
        db.query(CreditCardStatement, Account)
        .join(Account, Account.id == CreditCardStatement.account_id)
        .filter(CreditCardStatement.user_id == current_user.id)
    )

    if month:
        query = query.filter(
            CreditCardStatement.statement_reference == month,
        )

    rows = (
        query.order_by(
            desc(CreditCardStatement.due_date),
            desc(CreditCardStatement.id),
        )
        .all()
    )

    return [
        CreditCardStatementListItem(
            id=statement.id,
            account_id=statement.account_id,
            account_name=account.name,
            institution_name=account.institution_name,
            statement_reference=statement.statement_reference,
            statement_name=statement.statement_name,
            period_start=statement.period_start,
            period_end=statement.period_end,
            due_date=statement.due_date,
            closing_date=statement.closing_date,
            charges_total=statement.total_charges or Decimal("0"),
            payments_total=statement.total_payments or Decimal("0"),
            statement_balance=statement.statement_balance or Decimal("0"),
            reconciliation_status=statement.reconciliation_status,
        )
        for statement, account in rows
    ]