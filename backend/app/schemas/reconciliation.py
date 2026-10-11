from datetime import date
from decimal import Decimal

from pydantic import BaseModel, Field


class ReconciliationTransactionRead(BaseModel):
    id: int
    account_id: int
    date: date
    amount: Decimal
    amount_abs: Decimal
    account_type: str
    cashflow_type: str
    operation_type: str
    display_description: str | None = None
    reconciliation_status: str
    is_reconciled: bool


class ManualCardPaymentReconciliationRequest(BaseModel):
    bank_payment_transaction_id: int = Field(gt=0)
    card_payment_transaction_id: int = Field(gt=0)


class IgnoreReconciliationRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=500)


class ReconciliationPairRead(BaseModel):
    bank_payment: ReconciliationTransactionRead
    card_payment: ReconciliationTransactionRead


class ReconciliationResponse(BaseModel):
    success: bool
    message: str
    pair: ReconciliationPairRead


class StatementReconciliationResponse(BaseModel):
    success: bool
    statement_id: int
    statement_status: str
    matched: int
    pending: int
    ambiguous: int
    ignored: int
    message: str
    matched_pairs: list[ReconciliationPairRead]
    pending_card_payments: list[ReconciliationTransactionRead]
    ambiguous_card_payments: list[ReconciliationTransactionRead]


class IgnoreReconciliationResponse(BaseModel):
    success: bool
    transaction_id: int
    reconciliation_status: str
    message: str

class ManualCandidateGroupRead(BaseModel):
    card_payment: ReconciliationTransactionRead
    bank_candidates: list[ReconciliationTransactionRead]


class StatementManualCandidatesResponse(BaseModel):
    statement_id: int
    day_window: int
    items: list[ManualCandidateGroupRead]