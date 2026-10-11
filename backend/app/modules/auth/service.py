from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import DUMMY_PASSWORD_HASH, hash_password, verify_password
from app.db.models import User


def normalize_email(email: str) -> str:
    return email.strip().lower()


def get_user_by_email(db: Session, email: str) -> User | None:
    normalized_email = normalize_email(email)

    statement = select(User).where(User.email == normalized_email)

    return db.scalar(statement)


def get_user_by_id(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def create_user(db: Session, name: str, email: str, password: str) -> User:
    normalized_email = normalize_email(email)

    existing_user = get_user_by_email(db, normalized_email)

    if existing_user is not None:
        raise ValueError("Email already registered")

    user = User(
        name=name.strip(),
        email=normalized_email,
        password_hash=hash_password(password),
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


def authenticate_user(db: Session, email: str, password: str) -> User | None:
    user = get_user_by_email(db, email)

    if user is None:
        # Evita diferença grande de tempo entre email existente e inexistente.
        verify_password(password, DUMMY_PASSWORD_HASH)
        return None

    if not verify_password(password, user.password_hash):
        return None

    return user