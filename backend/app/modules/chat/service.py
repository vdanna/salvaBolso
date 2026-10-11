from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import ChatMessage, ChatSession
from app.modules.chat.context import build_financial_context, build_financial_prompt
from app.modules.gemini.client import generate_gemini_response


def create_chat_session(
    db: Session,
    user_id: int,
    title: str | None = None,
) -> ChatSession:
    session = ChatSession(
        user_id=user_id,
        title=title.strip() if title else "Nova conversa financeira",
    )

    db.add(session)
    db.commit()
    db.refresh(session)

    return session


def get_user_chat_sessions(
    db: Session,
    user_id: int,
) -> list[ChatSession]:
    statement = (
        select(ChatSession)
        .where(ChatSession.user_id == user_id)
        .order_by(ChatSession.updated_at.desc(), ChatSession.id.desc())
    )

    return list(db.scalars(statement).all())


def get_chat_session_by_id(
    db: Session,
    user_id: int,
    session_id: int,
) -> ChatSession | None:
    statement = (
        select(ChatSession)
        .where(ChatSession.id == session_id)
        .where(ChatSession.user_id == user_id)
    )

    return db.scalar(statement)


def get_chat_messages(
    db: Session,
    user_id: int,
    session_id: int,
) -> list[ChatMessage]:
    statement = (
        select(ChatMessage)
        .where(ChatMessage.user_id == user_id)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.id.asc())
    )

    return list(db.scalars(statement).all())


def save_chat_message(
    db: Session,
    user_id: int,
    session_id: int,
    role: str,
    content: str,
) -> ChatMessage:
    message = ChatMessage(
        user_id=user_id,
        session_id=session_id,
        role=role,
        content=content,
    )

    db.add(message)
    db.flush()

    return message


def send_financial_chat_message(
    db: Session,
    user_id: int,
    session_id: int,
    user_message: str,
    month: str | None = None,
) -> dict:
    session = get_chat_session_by_id(
        db=db,
        user_id=user_id,
        session_id=session_id,
    )

    if session is None:
        raise ValueError("Sessão de chat não encontrada.")

    financial_context = build_financial_context(
        db=db,
        user_id=user_id,
        month=month,
        user_question=user_message,
    )

    prompt = build_financial_prompt(
        user_question=user_message,
        financial_context=financial_context,
    )

    assistant_response = generate_gemini_response(prompt)

    saved_user_message = save_chat_message(
        db=db,
        user_id=user_id,
        session_id=session_id,
        role="user",
        content=user_message,
    )

    saved_assistant_message = save_chat_message(
        db=db,
        user_id=user_id,
        session_id=session_id,
        role="assistant",
        content=assistant_response,
    )

    db.add(session)
    db.commit()

    db.refresh(saved_user_message)
    db.refresh(saved_assistant_message)

    return {
        "session_id": session_id,
        "user_message": saved_user_message,
        "assistant_message": saved_assistant_message,
    }

def delete_chat_session(
    db: Session,
    user_id: int,
    session_id: int,
) -> bool:
    session = get_chat_session_by_id(
        db=db,
        user_id=user_id,
        session_id=session_id,
    )

    if session is None:
        return False

    db.delete(session)
    db.commit()

    return True