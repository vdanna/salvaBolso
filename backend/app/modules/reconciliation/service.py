from datetime import timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import CreditCardStatement, Transaction


CARD_PAYMENT_RECEIVED = "credit_card_payment_received"
BANK_CARD_BILL_PAYMENT = "credit_card_bill_payment"


def serialize_transaction(transaction: Transaction) -> dict:
    return {
        "id": transaction.id,
        "account_id": transaction.account_id,
        "date": transaction.date,
        "amount": transaction.amount,
        "amount_abs": transaction.amount_abs,
        "account_type": transaction.account_type,
        "cashflow_type": transaction.cashflow_type,
        "operation_type": transaction.operation_type,
        "display_description": transaction.display_description,
        "reconciliation_status": transaction.reconciliation_status,
        "is_reconciled": transaction.is_reconciled,
    }


def serialize_pair(
    bank_payment: Transaction,
    card_payment: Transaction,
) -> dict:
    return {
        "bank_payment": serialize_transaction(bank_payment),
        "card_payment": serialize_transaction(card_payment),
    }


def get_statement_by_id(
    db: Session,
    user_id: int,
    statement_id: int,
) -> CreditCardStatement | None:
    statement = (
        select(CreditCardStatement)
        .where(CreditCardStatement.id == statement_id)
        .where(CreditCardStatement.user_id == user_id)
    )

    return db.scalar(statement)


def get_transaction_by_id(
    db: Session,
    user_id: int,
    transaction_id: int,
) -> Transaction | None:
    statement = (
        select(Transaction)
        .where(Transaction.id == transaction_id)
        .where(Transaction.user_id == user_id)
    )

    return db.scalar(statement)


def get_pending_card_payments_for_statement(
    db: Session,
    user_id: int,
    statement_id: int,
) -> list[Transaction]:
    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .where(Transaction.statement_id == statement_id)
        .where(Transaction.operation_type == CARD_PAYMENT_RECEIVED)
        .where(Transaction.reconciliation_status == "pending")
        .where(Transaction.is_reconciled.is_(False))
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    return list(db.scalars(statement).all())


def get_all_card_payments_for_statement(
    db: Session,
    user_id: int,
    statement_id: int,
) -> list[Transaction]:
    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .where(Transaction.statement_id == statement_id)
        .where(Transaction.operation_type == CARD_PAYMENT_RECEIVED)
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    return list(db.scalars(statement).all())


def find_bank_payment_candidates_for_card_payment(
    db: Session,
    user_id: int,
    card_payment: Transaction,
    day_window: int = 3,
) -> list[Transaction]:
    start_date = card_payment.date - timedelta(days=day_window)
    end_date = card_payment.date + timedelta(days=day_window)

    statement = (
        select(Transaction)
        .where(Transaction.user_id == user_id)
        .where(Transaction.account_type == "checking")
        .where(Transaction.operation_type == BANK_CARD_BILL_PAYMENT)
        .where(Transaction.cashflow_type == "debt_payment")
        .where(Transaction.amount_abs == card_payment.amount_abs)
        .where(Transaction.date >= start_date)
        .where(Transaction.date <= end_date)
        .where(Transaction.reconciliation_status == "pending")
        .where(Transaction.is_reconciled.is_(False))
        .order_by(Transaction.date.asc(), Transaction.id.asc())
    )

    return list(db.scalars(statement).all())


def validate_bank_card_payment_transaction(transaction: Transaction) -> None:
    if transaction.account_type != "checking":
        raise ValueError("A transação bancária precisa pertencer a uma conta corrente.")

    if transaction.operation_type != BANK_CARD_BILL_PAYMENT:
        raise ValueError("A transação bancária precisa ser um pagamento de fatura.")

    if transaction.cashflow_type != "debt_payment":
        raise ValueError("A transação bancária precisa estar classificada como debt_payment.")

    if transaction.is_reconciled:
        raise ValueError("A transação bancária já está conciliada.")

    if transaction.reconciliation_status != "pending":
        raise ValueError("A transação bancária não está pendente de conciliação.")


def validate_credit_card_payment_transaction(transaction: Transaction) -> None:
    if transaction.account_type != "credit_card":
        raise ValueError("A transação do cartão precisa pertencer a uma conta do tipo credit_card.")

    if transaction.operation_type != CARD_PAYMENT_RECEIVED:
        raise ValueError("A transação do cartão precisa ser um pagamento recebido na fatura.")

    if transaction.cashflow_type != "liability_decrease":
        raise ValueError("A transação do cartão precisa estar classificada como liability_decrease.")

    if transaction.is_reconciled:
        raise ValueError("A transação do cartão já está conciliada.")

    if transaction.reconciliation_status != "pending":
        raise ValueError("A transação do cartão não está pendente de conciliação.")


def validate_payment_values(
    bank_payment: Transaction,
    card_payment: Transaction,
) -> None:
    bank_amount = Decimal(bank_payment.amount_abs)
    card_amount = Decimal(card_payment.amount_abs)

    if bank_amount != card_amount:
        raise ValueError(
            "As transações não possuem o mesmo valor absoluto."
        )


def update_statement_reconciliation_status(
    db: Session,
    user_id: int,
    statement: CreditCardStatement,
) -> str:
    card_payments = get_all_card_payments_for_statement(
        db=db,
        user_id=user_id,
        statement_id=statement.id,
    )

    if not card_payments:
        statement.reconciliation_status = "no_payments"
        db.add(statement)
        db.flush()
        return statement.reconciliation_status

    reconciled_count = sum(
        1
        for payment in card_payments
        if payment.reconciliation_status == "reconciled"
    )

    ignored_count = sum(
        1
        for payment in card_payments
        if payment.reconciliation_status == "ignored"
    )

    pending_count = sum(
        1
        for payment in card_payments
        if payment.reconciliation_status == "pending"
    )

    total_count = len(card_payments)

    if reconciled_count == total_count:
        statement.reconciliation_status = "reconciled"
    elif ignored_count == total_count:
        statement.reconciliation_status = "ignored"
    elif pending_count == 0 and reconciled_count > 0:
        statement.reconciliation_status = "reconciled"
    elif reconciled_count > 0:
        statement.reconciliation_status = "partially_reconciled"
    else:
        statement.reconciliation_status = "pending"

    db.add(statement)
    db.flush()

    return statement.reconciliation_status


def reconcile_payment_pair(
    db: Session,
    user_id: int,
    bank_payment: Transaction,
    card_payment: Transaction,
) -> dict:
    validate_bank_card_payment_transaction(bank_payment)
    validate_credit_card_payment_transaction(card_payment)
    validate_payment_values(
        bank_payment=bank_payment,
        card_payment=card_payment,
    )

    bank_payment.is_reconciled = True
    bank_payment.reconciliation_status = "reconciled"
    bank_payment.reconciled_transaction_id = card_payment.id
    bank_payment.is_card_payment = True

    card_payment.is_reconciled = True
    card_payment.reconciliation_status = "reconciled"
    card_payment.reconciled_transaction_id = bank_payment.id
    card_payment.is_card_payment = True

    db.add(bank_payment)
    db.add(card_payment)

    statement = None

    if card_payment.statement_id is not None:
        statement = get_statement_by_id(
            db=db,
            user_id=user_id,
            statement_id=card_payment.statement_id,
        )

    if statement is not None:
        if statement.matched_bank_payment_id is None:
            statement.matched_bank_payment_id = bank_payment.id

        if statement.matched_card_payment_id is None:
            statement.matched_card_payment_id = card_payment.id

        db.add(statement)

    db.flush()

    if statement is not None:
        update_statement_reconciliation_status(
            db=db,
            user_id=user_id,
            statement=statement,
        )

    return serialize_pair(
        bank_payment=bank_payment,
        card_payment=card_payment,
    )


def manually_reconcile_card_payment(
    db: Session,
    user_id: int,
    bank_payment_transaction_id: int,
    card_payment_transaction_id: int,
) -> dict:
    bank_payment = get_transaction_by_id(
        db=db,
        user_id=user_id,
        transaction_id=bank_payment_transaction_id,
    )

    if bank_payment is None:
        raise ValueError("Transação bancária não encontrada.")

    card_payment = get_transaction_by_id(
        db=db,
        user_id=user_id,
        transaction_id=card_payment_transaction_id,
    )

    if card_payment is None:
        raise ValueError("Transação do cartão não encontrada.")

    pair = reconcile_payment_pair(
        db=db,
        user_id=user_id,
        bank_payment=bank_payment,
        card_payment=card_payment,
    )

    db.commit()

    return pair


def auto_reconcile_statement(
    db: Session,
    user_id: int,
    statement: CreditCardStatement,
    day_window: int = 3,
) -> dict:
    pending_card_payments = get_pending_card_payments_for_statement(
        db=db,
        user_id=user_id,
        statement_id=statement.id,
    )

    matched_pairs: list[dict] = []
    pending_after_attempt: list[Transaction] = []
    ambiguous_card_payments: list[Transaction] = []

    for card_payment in pending_card_payments:
        candidates = find_bank_payment_candidates_for_card_payment(
            db=db,
            user_id=user_id,
            card_payment=card_payment,
            day_window=day_window,
        )

        if len(candidates) == 1:
            bank_payment = candidates[0]

            pair = reconcile_payment_pair(
                db=db,
                user_id=user_id,
                bank_payment=bank_payment,
                card_payment=card_payment,
            )

            matched_pairs.append(pair)

        elif len(candidates) > 1:
            ambiguous_card_payments.append(card_payment)

        else:
            pending_after_attempt.append(card_payment)

    statement_status = update_statement_reconciliation_status(
        db=db,
        user_id=user_id,
        statement=statement,
    )

    db.commit()

    return {
        "statement_status": statement_status,
        "matched": len(matched_pairs),
        "pending": len(pending_after_attempt),
        "ambiguous": len(ambiguous_card_payments),
        "ignored": 0,
        "matched_pairs": matched_pairs,
        "pending_card_payments": [
            serialize_transaction(transaction)
            for transaction in pending_after_attempt
        ],
        "ambiguous_card_payments": [
            serialize_transaction(transaction)
            for transaction in ambiguous_card_payments
        ],
    }


def ignore_transaction_reconciliation(
    db: Session,
    user_id: int,
    transaction_id: int,
    reason: str | None = None,
) -> Transaction:
    transaction = get_transaction_by_id(
        db=db,
        user_id=user_id,
        transaction_id=transaction_id,
    )

    if transaction is None:
        raise ValueError("Transação não encontrada.")

    if transaction.is_reconciled:
        raise ValueError("Uma transação já conciliada não pode ser ignorada.")

    transaction.reconciliation_status = "ignored"

    if reason:
        current_notes = transaction.notes or ""
        separator = "\n" if current_notes else ""
        transaction.notes = (
            f"{current_notes}{separator}"
            f"Conciliação ignorada: {reason.strip()}"
        )

    db.add(transaction)

    statement = None

    if transaction.statement_id is not None:
        statement = get_statement_by_id(
            db=db,
            user_id=user_id,
            statement_id=transaction.statement_id,
        )

    if statement is not None:
        update_statement_reconciliation_status(
            db=db,
            user_id=user_id,
            statement=statement,
        )

    db.commit()
    db.refresh(transaction)

    return transaction