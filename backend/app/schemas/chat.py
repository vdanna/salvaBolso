from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ChatSessionCreate(BaseModel):
    title: str | None = Field(default=None, max_length=120)


class ChatSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class ChatMessageCreate(BaseModel):
    message: str = Field(min_length=2, max_length=4000)
    month: str | None = Field(
        default=None,
        pattern=r"^\d{4}-\d{2}$",
        description="Mês de referência no formato YYYY-MM. Exemplo: 2026-05.",
    )


class ChatMessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    session_id: int
    role: str
    content: str
    created_at: datetime | None = None


class ChatMessageResponse(BaseModel):
    session_id: int
    user_message: ChatMessageRead
    assistant_message: ChatMessageRead