from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import ChatMessage, ChatSession, User
from app.modules.chat.service import (
    create_chat_session,
    get_chat_messages,
    get_chat_session_by_id,
    get_user_chat_sessions,
    send_financial_chat_message,
    delete_chat_session,
)
from app.schemas.chat import (
    ChatMessageCreate,
    ChatMessageRead,
    ChatMessageResponse,
    ChatSessionCreate,
    ChatSessionRead,
)


router = APIRouter(prefix="/chat", tags=["chat"])


@router.post(
    "/sessions",
    response_model=ChatSessionRead,
    status_code=status.HTTP_201_CREATED,
)
def create_chat_session_endpoint(
    payload: ChatSessionCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> ChatSession:
    return create_chat_session(
        db=db,
        user_id=current_user.id,
        title=payload.title,
    )


@router.get(
    "/sessions",
    response_model=list[ChatSessionRead],
)
def list_chat_sessions_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[ChatSession]:
    return get_user_chat_sessions(
        db=db,
        user_id=current_user.id,
    )


@router.get(
    "/sessions/{session_id}/messages",
    response_model=list[ChatMessageRead],
)
def list_chat_messages_endpoint(
    session_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[ChatMessage]:
    session = get_chat_session_by_id(
        db=db,
        user_id=current_user.id,
        session_id=session_id,
    )

    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sessão de chat não encontrada.",
        )

    return get_chat_messages(
        db=db,
        user_id=current_user.id,
        session_id=session_id,
    )


@router.post(
    "/sessions/{session_id}/messages",
    response_model=ChatMessageResponse,
)
def send_chat_message_endpoint(
    session_id: int,
    payload: ChatMessageCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    try:
        return send_financial_chat_message(
            db=db,
            user_id=current_user.id,
            session_id=session_id,
            user_message=payload.message,
            month=payload.month,
        )

    except ValueError as error:
        error_message = str(error)

        if "Sessão de chat não encontrada" in error_message:
            status_code = status.HTTP_404_NOT_FOUND
        elif "GEMINI_API_KEY" in error_message:
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        else:
            status_code = status.HTTP_400_BAD_REQUEST

        raise HTTPException(
            status_code=status_code,
            detail=error_message,
        ) from error
    

@router.delete(
    "/sessions/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_chat_session_endpoint(
    session_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    deleted = delete_chat_session(
        db=db,
        user_id=current_user.id,
        session_id=session_id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sessão de chat não encontrada.",
        )