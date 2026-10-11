from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import User
from app.modules.summaries.service import (
    get_cashflow_summary,
    get_categories_summary,
    get_consumption_summary,
    get_credit_card_installments_summary,
    get_credit_card_merchants_summary,
    get_health_score,
    get_recurring_expenses,
    get_statement_summary,
    get_available_transaction_months,
    get_overall_dashboard_summary,
)
from app.schemas.summaries import (
    CashflowSummaryResponse,
    CategoriesSummaryResponse,
    ConsumptionSummaryResponse,
    CreditCardInstallmentsSummaryResponse,
    CreditCardMerchantsSummaryResponse,
    HealthScoreResponse,
    RecurringExpensesResponse,
    StatementSummaryResponse,
)


router = APIRouter(prefix="/summary", tags=["summary"])


MonthQuery = Annotated[
    str,
    Query(
        pattern=r"^\d{4}-\d{2}$",
        description="Mês no formato YYYY-MM. Exemplo: 2026-05.",
    ),
]


@router.get("/months")
def available_months_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    return {
        "items": get_available_transaction_months(
            db=db,
            user_id=current_user.id,
        )
    }


@router.get("/overview")
def overall_dashboard_summary_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    return get_overall_dashboard_summary(
        db=db,
        user_id=current_user.id,
    )


@router.get("/cashflow", response_model=CashflowSummaryResponse)
def cashflow_summary_endpoint(
    month: MonthQuery,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        return get_cashflow_summary(
            db=db,
            user_id=current_user.id,
            month=month,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get("/consumption", response_model=ConsumptionSummaryResponse)
def consumption_summary_endpoint(
    month: MonthQuery,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    basis: Literal["purchase_date"] = "purchase_date",
) -> dict:
    try:
        return get_consumption_summary(
            db=db,
            user_id=current_user.id,
            month=month,
            basis=basis,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get(
    "/statements/{statement_id}",
    response_model=StatementSummaryResponse,
)
def statement_summary_endpoint(
    statement_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    result = get_statement_summary(
        db=db,
        user_id=current_user.id,
        statement_id=statement_id,
    )

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fatura não encontrada.",
        )

    return result


@router.get("/categories", response_model=CategoriesSummaryResponse)
def categories_summary_endpoint(
    month: MonthQuery,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    view: Literal["consumption", "cashflow"] = "consumption",
) -> dict:
    try:
        return get_categories_summary(
            db=db,
            user_id=current_user.id,
            month=month,
            view=view,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get(
    "/credit-card/merchants",
    response_model=CreditCardMerchantsSummaryResponse,
)
def credit_card_merchants_summary_endpoint(
    month: MonthQuery,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        return get_credit_card_merchants_summary(
            db=db,
            user_id=current_user.id,
            month=month,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get(
    "/credit-card/installments",
    response_model=CreditCardInstallmentsSummaryResponse,
)
def credit_card_installments_summary_endpoint(
    month: MonthQuery,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        return get_credit_card_installments_summary(
            db=db,
            user_id=current_user.id,
            month=month,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get(
    "/recurring-expenses",
    response_model=RecurringExpensesResponse,
)
def recurring_expenses_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    months_back: Annotated[int, Query(ge=2, le=24)] = 6,
    minimum_occurrences: Annotated[int, Query(ge=2, le=12)] = 2,
) -> dict:
    try:
        return get_recurring_expenses(
            db=db,
            user_id=current_user.id,
            months_back=months_back,
            minimum_occurrences=minimum_occurrences,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get("/health-score", response_model=HealthScoreResponse)
def health_score_endpoint(
    month: MonthQuery,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        return get_health_score(
            db=db,
            user_id=current_user.id,
            month=month,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error