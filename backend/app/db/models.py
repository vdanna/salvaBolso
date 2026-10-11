
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    accounts: Mapped[list["Account"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )
    categories: Mapped[list["Category"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )


class Account(Base, TimestampMixin):
    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name: Mapped[str] = mapped_column(String(120), nullable=False)
    institution_name: Mapped[str] = mapped_column(String(120), nullable=False)
    account_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)

    user: Mapped["User"] = relationship(back_populates="accounts")
    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="account",
        cascade="all, delete-orphan",
    )
    import_batches: Mapped[list["ImportBatch"]] = relationship(
        back_populates="account",
        cascade="all, delete-orphan",
    )
    credit_card_statements: Mapped[list["CreditCardStatement"]] = relationship(
        back_populates="account",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("ix_accounts_user_id_account_type", "user_id", "account_type"),
    )


#class Category(Base, TimestampMixin):
#    __tablename__ = "categories"
#
#    id: Mapped[int] = mapped_column(Integer, primary_key=True)
#    user_id: Mapped[int] = mapped_column(
#        ForeignKey("users.id", ondelete="CASCADE"),
#        nullable=False,
#        index=True,
#    )
#
#    name: Mapped[str] = mapped_column(String(120), nullable=False)
#    type: Mapped[str] = mapped_column(String(40), nullable=False, default="expense")
#
#    user: Mapped["User"] = relationship(back_populates="categories")
#    transactions: Mapped[list["Transaction"]] = relationship(back_populates="category")
#    rules: Mapped[list["CategoryRule"]] = relationship(
#        back_populates="category",
#        cascade="all, delete-orphan",
#    )
#    budgets: Mapped[list["Budget"]] = relationship(
#        back_populates="category",
#        cascade="all, delete-orphan",
#    )
#
#    __table_args__ = (
#        UniqueConstraint("user_id", "name", name="uq_categories_user_name"),
#    )


#class CategoryRule(Base, TimestampMixin):
#    __tablename__ = "category_rules"
#
#    id: Mapped[int] = mapped_column(Integer, primary_key=True)
#
#    user_id: Mapped[int] = mapped_column(
#        ForeignKey("users.id", ondelete="CASCADE"),
#        nullable=False,
#        index=True,
#    )
#    category_id: Mapped[int] = mapped_column(
#        ForeignKey("categories.id", ondelete="CASCADE"),
#        nullable=False,
#        index=True,
#    )
#
#    field: Mapped[str] = mapped_column(String(80), nullable=False)
#    operator: Mapped[str] = mapped_column(String(40), nullable=False)
#    value: Mapped[str] = mapped_column(String(255), nullable=False)
#    priority: Mapped[int] = mapped_column(Integer, nullable=False, default=100)
#    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
#
#    category: Mapped["Category"] = relationship(back_populates="rules")

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    parent_id = Column(
        Integer,
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    name = Column(String(120), nullable=False)
    color = Column(String(20), nullable=False, default="#737373")
    lucide_icon = Column(String(80), nullable=False, default="circle-dashed")

    classification = Column(
        String(30),
        nullable=False,
        default="expense",
        index=True,
    )

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    parent = relationship(
        "Category",
        remote_side=[id],
        backref="subcategories",
    )

    transactions = relationship(
        "Transaction",
        back_populates="category",
    )

    rules = relationship(
        "CategoryRule",
        back_populates="category",
        cascade="all, delete-orphan",
    )

    budgets = relationship(
        "Budget",
        back_populates="category",
        cascade="all, delete-orphan",
    )

    user = relationship("User")

class CategoryRule(Base):
    __tablename__ = "category_rules"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    category_id = Column(
        Integer,
        ForeignKey("categories.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    pattern = Column(String(200), nullable=False)
    match_type = Column(String(30), nullable=False, default="contains")
    field = Column(String(50), nullable=False, default="description")
    priority = Column(Integer, nullable=False, default=100)
    is_active = Column(Boolean, nullable=False, default=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    category = relationship(
        "Category",
        back_populates="rules",
    )
    user = relationship("User")


class ImportBatch(Base, TimestampMixin):
    __tablename__ = "import_batches"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    account_id: Mapped[int] = mapped_column(
        ForeignKey("accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_hash: Mapped[str] = mapped_column(String(128), nullable=False)

    source: Mapped[str] = mapped_column(String(40), nullable=False, default="csv")
    source_format: Mapped[str] = mapped_column(String(80), nullable=False)

    period_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    period_end: Mapped[date | None] = mapped_column(Date, nullable=True)

    total_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    imported_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    duplicate_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    error_rows: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    status: Mapped[str] = mapped_column(String(40), nullable=False, default="pending")

    account: Mapped["Account"] = relationship(back_populates="import_batches")
    transactions: Mapped[list["Transaction"]] = relationship(back_populates="import_batch")

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "account_id",
            "file_hash",
            name="uq_import_batches_user_account_file_hash",
        ),
    )


class CreditCardStatement(Base, TimestampMixin):
    __tablename__ = "credit_card_statements"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    account_id: Mapped[int] = mapped_column(
        ForeignKey("accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    statement_reference: Mapped[str | None] = mapped_column(String(40), nullable=True)
    statement_name: Mapped[str | None] = mapped_column(String(160), nullable=True)

    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_hash: Mapped[str] = mapped_column(String(128), nullable=False)

    period_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    period_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    closing_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    total_charges: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=0)
    total_payments: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=0)
    statement_balance: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=0)

    #matched_bank_payment_id: Mapped[int | None] = mapped_column(
    #    ForeignKey("transactions.id", ondelete="SET NULL"),
    #    nullable=True,
    #)
    #matched_card_payment_id: Mapped[int | None] = mapped_column(
    #    ForeignKey("transactions.id", ondelete="SET NULL"),
    #    nullable=True,
    #)

    matched_bank_payment_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )
    
    matched_card_payment_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
    )

    reconciliation_status: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="pending",
    )

    account: Mapped["Account"] = relationship(back_populates="credit_card_statements")
    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="statement",
        foreign_keys="Transaction.statement_id",
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "account_id",
            "file_hash",
            name="uq_credit_card_statements_user_account_file_hash",
        ),
    )


class Transaction(Base, TimestampMixin):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    account_id: Mapped[int] = mapped_column(
        ForeignKey("accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    amount_abs: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)

    account_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    source: Mapped[str] = mapped_column(String(40), nullable=False, default="csv")
    source_format: Mapped[str] = mapped_column(String(80), nullable=False, index=True)

    description: Mapped[str] = mapped_column(String(255), nullable=False)
    display_description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    raw_description: Mapped[str | None] = mapped_column(Text, nullable=True)

    cash_direction: Mapped[str] = mapped_column(String(40), nullable=False, default="none")
    liability_direction: Mapped[str] = mapped_column(String(40), nullable=False, default="none")
    cashflow_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    operation_type: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    payment_method: Mapped[str] = mapped_column(String(80), nullable=False, default="unknown")

    category_id: Mapped[int | None] = mapped_column(
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    merchant_name: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    counterparty_name: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)

    counterparty_document: Mapped[str | None] = mapped_column(String(80), nullable=True)
    counterparty_institution: Mapped[str | None] = mapped_column(String(160), nullable=True)
    counterparty_bank_code: Mapped[str | None] = mapped_column(String(20), nullable=True)
    counterparty_agency: Mapped[str | None] = mapped_column(String(40), nullable=True)
    counterparty_account: Mapped[str | None] = mapped_column(String(80), nullable=True)

    external_id: Mapped[str | None] = mapped_column(String(160), nullable=True, index=True)
    fingerprint: Mapped[str] = mapped_column(String(128), nullable=False, unique=True, index=True)

    import_batch_id: Mapped[int | None] = mapped_column(
        ForeignKey("import_batches.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    statement_id: Mapped[int | None] = mapped_column(
        ForeignKey("credit_card_statements.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    billing_cycle_id: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)

    installment_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    installment_total: Mapped[int | None] = mapped_column(Integer, nullable=True)
    installment_group_key: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)

    is_card_payment: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_reconciled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    reconciled_transaction_id: Mapped[int | None] = mapped_column(
        ForeignKey("transactions.id", ondelete="SET NULL"),
        nullable=True,
    )
    reconciliation_status: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="pending",
    )

    is_internal_transfer: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    related_external_id: Mapped[str | None] = mapped_column(String(160), nullable=True)

    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict[str, Any] | None] = mapped_column(
        "metadata",
        JSON,
        nullable=True,
    )

    account: Mapped["Account"] = relationship(back_populates="transactions")
    category: Mapped["Category"] = relationship(back_populates="transactions")
    import_batch: Mapped["ImportBatch"] = relationship(back_populates="transactions")
    statement: Mapped["CreditCardStatement"] = relationship(
        back_populates="transactions",
        foreign_keys=[statement_id],
    )

    __table_args__ = (
        Index("ix_transactions_user_date", "user_id", "date"),
        Index("ix_transactions_user_cashflow_type", "user_id", "cashflow_type"),
        Index("ix_transactions_user_operation_type", "user_id", "operation_type"),
    )


class Budget(Base, TimestampMixin):
    __tablename__ = "budgets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    category_id: Mapped[int] = mapped_column(
        ForeignKey("categories.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    month: Mapped[str] = mapped_column(String(7), nullable=False, index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)

    category: Mapped["Category"] = relationship(back_populates="budgets")

    __table_args__ = (
        UniqueConstraint("user_id", "category_id", "month", name="uq_budgets_user_category_month"),
    )


class ChatSession(Base, TimestampMixin):
    __tablename__ = "chat_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    title: Mapped[str | None] = mapped_column(String(160), nullable=True)

    messages: Mapped[list["ChatMessage"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    session_id: Mapped[int] = mapped_column(
        ForeignKey("chat_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    role: Mapped[str] = mapped_column(String(40), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    session: Mapped["ChatSession"] = relationship(back_populates="messages")


class SystemLog(Base):
    __tablename__ = "system_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)

    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    event_type: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    metadata_json: Mapped[dict[str, Any] | None] = mapped_column(
        "metadata",
        JSON,
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )