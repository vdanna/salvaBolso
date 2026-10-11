from datetime import date
from decimal import Decimal

from pydantic import BaseModel


class SummaryTransactionRead(BaseModel):
    id: int
    date: date
    amount: Decimal
    amount_abs: Decimal
    account_type: str
    cashflow_type: str
    operation_type: str
    payment_method: str
    merchant_name: str | None = None
    display_description: str | None = None
    is_reconciled: bool
    reconciliation_status: str


class CashflowSummaryResponse(BaseModel):
    month: str
    period_start: date
    period_end: date

    transaction_count: int
    gross_inflow: Decimal
    gross_outflow: Decimal
    net_cashflow: Decimal

    income: Decimal
    expenses: Decimal
    debt_payments: Decimal
    liability_increase: Decimal

    card_bill_payments: Decimal
    reconciled_card_bill_payments: Decimal
    unreconciled_card_bill_payments: Decimal

    warnings: list[str]


class ConsumptionSummaryResponse(BaseModel):
    month: str
    basis: str
    period_start: date
    period_end: date

    transaction_count: int
    total_consumption: Decimal
    checking_consumption: Decimal
    credit_card_consumption: Decimal

    debit_card_total: Decimal
    pix_total: Decimal
    bank_slip_total: Decimal
    credit_card_total: Decimal
    nupay_total: Decimal

    installment_total: Decimal
    single_purchase_total: Decimal

    top_transactions: list[SummaryTransactionRead]
    warnings: list[str]


class StatementSummaryResponse(BaseModel):
    statement_id: int
    statement_reference: str | None
    statement_name: str | None
    file_name: str
    period_start: date | None
    period_end: date | None
    due_date: date | None

    total_charges: Decimal
    total_payments: Decimal
    statement_balance: Decimal
    reconciliation_status: str

    transaction_count: int
    purchase_count: int
    payment_count: int
    installment_count: int

    purchases_total: Decimal
    payments_total: Decimal
    installments_total: Decimal
    single_purchases_total: Decimal

    matched_bank_payment_id: int | None
    matched_card_payment_id: int | None

    transactions: list[SummaryTransactionRead]


class CategorySummaryItem(BaseModel):
    category_id: int | None
    category_name: str
    total: Decimal
    transaction_count: int
    percentage: Decimal


class CategoriesSummaryResponse(BaseModel):
    month: str
    view: str
    total: Decimal
    items: list[CategorySummaryItem]


class MerchantSummaryItem(BaseModel):
    merchant_name: str
    total: Decimal
    transaction_count: int
    percentage: Decimal


class CreditCardMerchantsSummaryResponse(BaseModel):
    month: str
    total: Decimal
    items: list[MerchantSummaryItem]


class InstallmentSummaryItem(BaseModel):
    installment_group_key: str | None
    merchant_name: str
    installment_total: int | None
    amount_in_month: Decimal
    transaction_count_in_month: int
    installments_seen: list[int]


class CreditCardInstallmentsSummaryResponse(BaseModel):
    month: str
    total_installments_in_month: Decimal
    items: list[InstallmentSummaryItem]


class RecurringExpenseItem(BaseModel):
    description: str
    merchant_name: str | None = None
    payment_method: str
    average_amount: Decimal
    last_amount: Decimal
    occurrences: int
    months_seen: list[str]


class RecurringExpensesResponse(BaseModel):
    months_back: int
    minimum_occurrences: int
    items: list[RecurringExpenseItem]


class HealthScoreResponse(BaseModel):
    month: str
    score: int
    status: str

    income: Decimal
    consumption: Decimal
    debt_payments: Decimal
    net_cashflow: Decimal

    consumption_rate: Decimal | None
    debt_payment_rate: Decimal | None
    cash_margin_rate: Decimal | None

    warnings: list[str]
    recommendations: list[str]