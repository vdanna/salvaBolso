from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import User
from app.modules.reconciliation.service import (
    auto_reconcile_statement,
    get_statement_by_id,
    ignore_transaction_reconciliation,
    manually_reconcile_card_payment,
    find_bank_payment_candidates_for_card_payment,
    get_pending_card_payments_for_statement,
    serialize_transaction,
)
from app.schemas.reconciliation import (
    IgnoreReconciliationRequest,
    IgnoreReconciliationResponse,
    ManualCardPaymentReconciliationRequest,
    ReconciliationResponse,
    StatementReconciliationResponse,
    StatementManualCandidatesResponse,
)


router = APIRouter(prefix="/reconciliation", tags=["reconciliation"])


@router.post(
    "/statements/{statement_id}",
    response_model=StatementReconciliationResponse,
)
def reconcile_statement_endpoint(
    statement_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    day_window: Annotated[int, Query(ge=0, le=30)] = 3,
) -> dict:
    statement = get_statement_by_id(
        db=db,
        user_id=current_user.id,
        statement_id=statement_id,
    )

    if statement is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fatura não encontrada.",
        )

    result = auto_reconcile_statement(
        db=db,
        user_id=current_user.id,
        statement=statement,
        day_window=day_window,
    )

    matched = result["matched"]
    pending = result["pending"]
    ambiguous = result["ambiguous"]

    if matched == 0 and pending == 0 and ambiguous == 0:
        message = "Não havia pagamentos pendentes para conciliar nesta fatura."
    elif matched > 0 and pending == 0 and ambiguous == 0:
        message = "Conciliação automática concluída com sucesso."
    elif matched > 0:
        message = "Conciliação parcialmente concluída. Algumas transações continuam pendentes ou ambíguas."
    elif ambiguous > 0:
        message = "Nenhuma conciliação automática foi feita porque há candidatos ambíguos."
    else:
        message = "Nenhum pagamento bancário correspondente foi encontrado."

    return {
        "success": True,
        "statement_id": statement_id,
        "statement_status": result["statement_status"],
        "matched": matched,
        "pending": pending,
        "ambiguous": ambiguous,
        "ignored": result["ignored"],
        "message": message,
        "matched_pairs": result["matched_pairs"],
        "pending_card_payments": result["pending_card_payments"],
        "ambiguous_card_payments": result["ambiguous_card_payments"],
    }


@router.get(
    "/statements/{statement_id}/manual-candidates",
    response_model=StatementManualCandidatesResponse,
)
def list_statement_manual_candidates_endpoint(
    statement_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    day_window: Annotated[int, Query(ge=0, le=30)] = 30,
) -> dict:
    statement = get_statement_by_id(
        db=db,
        user_id=current_user.id,
        statement_id=statement_id,
    )

    if statement is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fatura não encontrada.",
        )

    pending_card_payments = get_pending_card_payments_for_statement(
        db=db,
        user_id=current_user.id,
        statement_id=statement_id,
    )

    items = []

    for card_payment in pending_card_payments:
        bank_candidates = find_bank_payment_candidates_for_card_payment(
            db=db,
            user_id=current_user.id,
            card_payment=card_payment,
            day_window=day_window,
        )

        items.append(
            {
                "card_payment": serialize_transaction(card_payment),
                "bank_candidates": [
                    serialize_transaction(candidate)
                    for candidate in bank_candidates
                ],
            }
        )

    return {
        "statement_id": statement_id,
        "day_window": day_window,
        "items": items,
    }


@router.post(
    "/card-payment",
    response_model=ReconciliationResponse,
)
def manually_reconcile_card_payment_endpoint(
    payload: ManualCardPaymentReconciliationRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        pair = manually_reconcile_card_payment(
            db=db,
            user_id=current_user.id,
            bank_payment_transaction_id=payload.bank_payment_transaction_id,
            card_payment_transaction_id=payload.card_payment_transaction_id,
        )

        return {
            "success": True,
            "message": "Pagamento de fatura conciliado com sucesso.",
            "pair": pair,
        }

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.post(
    "/transactions/{transaction_id}/ignore",
    response_model=IgnoreReconciliationResponse,
)
def ignore_transaction_reconciliation_endpoint(
    transaction_id: int,
    payload: IgnoreReconciliationRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        transaction = ignore_transaction_reconciliation(
            db=db,
            user_id=current_user.id,
            transaction_id=transaction_id,
            reason=payload.reason,
        )

        return {
            "success": True,
            "transaction_id": transaction.id,
            "reconciliation_status": transaction.reconciliation_status,
            "message": "Transação marcada como ignorada para conciliação.",
        }

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error