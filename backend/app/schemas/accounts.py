from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


AccountType = Literal[
    "checking",
    "credit_card",
    "investment",
    "cash",
    "wallet",
]


class AccountCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    institution_name: str = Field(min_length=2, max_length=120)
    account_type: AccountType


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    institution_name: str | None = Field(default=None, min_length=2, max_length=120)
    account_type: AccountType | None = None


class AccountRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    institution_name: str
    account_type: str