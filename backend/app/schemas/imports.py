from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class AccountTransactionPreview(BaseModel):
    date: date
    amount: Decimal
    direction: str
    cashflow_type: str
    operation_type: str
    payment_method: str
    display_description: str | None = None
    raw_description: str | None = None
    external_id: str | None = None


class AccountCsvPreviewResponse(BaseModel):
    file_name: str
    format: str
    period_start: date | None
    period_end: date | None

    total_rows: int
    valid_rows: int
    error_rows: int

    gross_inflow: Decimal
    gross_outflow: Decimal
    net_cashflow: Decimal

    income: Decimal
    expenses: Decimal
    debt_payments: Decimal
    liability_increase: Decimal

    operation_types: list[str]
    warnings: list[str]
    sample_transactions: list[AccountTransactionPreview]


class AccountCsvImportResponse(BaseModel):
    success: bool
    import_batch_id: int
    file_name: str
    format: str
    period_start: date | None
    period_end: date | None

    total_rows: int
    imported: int
    duplicates: int
    errors: list[str]
    warnings: list[str]


class ImportBatchRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    account_id: int
    file_name: str
    file_hash: str
    source: str
    source_format: str
    period_start: date | None
    period_end: date | None
    total_rows: int
    imported_rows: int
    duplicate_rows: int
    error_rows: int
    status: str

class CreditCardTransactionPreview(BaseModel):
    date: date
    amount: Decimal
    liability_direction: str
    cashflow_type: str
    operation_type: str
    payment_method: str
    merchant_name: str | None = None
    display_description: str | None = None
    raw_description: str | None = None
    installment_number: int | None = None
    installment_total: int | None = None
    is_card_payment: bool


class CreditCardCsvPreviewResponse(BaseModel):
    file_name: str
    format: str
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

    warnings: list[str]
    sample_transactions: list[CreditCardTransactionPreview]


class CreditCardCsvImportResponse(BaseModel):
    success: bool
    statement_id: int
    import_batch_id: int
    file_name: str
    format: str
    period_start: date | None
    period_end: date | None
    due_date: date | None
    statement_reference: str | None

    total_rows: int
    imported: int
    duplicates: int
    purchase_rows: int
    payment_rows: int
    installment_rows: int
    matched_payments: int
    pending_payments: int

    errors: list[str]
    warnings: list[str]