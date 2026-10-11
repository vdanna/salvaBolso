from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


Classification = Literal["income", "expense"]


class CategoryCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    color: str = "#737373"
    lucide_icon: str = "circle-dashed"
    classification: Classification = "expense"
    parent_id: int | None = None


class CategoryRead(BaseModel):
    id: int
    user_id: int
    parent_id: int | None = None
    name: str
    color: str
    lucide_icon: str
    classification: str
    created_at: datetime | None = None
    updated_at: datetime | None = None


class CategoryRuleCreate(BaseModel):
    category_id: int
    pattern: str = Field(min_length=1, max_length=200)
    match_type: Literal["contains", "equals", "starts_with"] = "contains"
    field: Literal["description", "merchant", "all"] = "description"
    priority: int = 100


class CategoryRuleRead(BaseModel):
    id: int
    user_id: int
    category_id: int
    pattern: str
    match_type: str
    field: str
    priority: int
    is_active: bool
    created_at: datetime | None = None
    updated_at: datetime | None = None


class ReplaceCategoryRequest(BaseModel):
    replacement_category_id: int | None = None


class CategorizeTransactionsResponse(BaseModel):
    processed: int
    categorized: int
    uncategorized: int