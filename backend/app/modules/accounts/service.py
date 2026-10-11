from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Account


def get_account_by_id(
    db: Session,
    user_id: int,
    account_id: int,
) -> Account | None:
    statement = (
        select(Account)
        .where(Account.id == account_id)
        .where(Account.user_id == user_id)
    )

    return db.scalar(statement)


def get_accounts(db: Session, user_id: int) -> list[Account]:
    statement = (
        select(Account)
        .where(Account.user_id == user_id)
        .order_by(Account.id.asc())
    )

    return list(db.scalars(statement).all())


def account_exists_with_same_data(
    db: Session,
    user_id: int,
    name: str,
    institution_name: str,
    account_type: str,
    ignore_account_id: int | None = None,
) -> bool:
    statement = (
        select(Account)
        .where(Account.user_id == user_id)
        .where(Account.name == name.strip())
        .where(Account.institution_name == institution_name.strip())
        .where(Account.account_type == account_type)
    )

    if ignore_account_id is not None:
        statement = statement.where(Account.id != ignore_account_id)

    return db.scalar(statement) is not None


def create_account(
    db: Session,
    user_id: int,
    name: str,
    institution_name: str,
    account_type: str,
) -> Account:
    clean_name = name.strip()
    clean_institution_name = institution_name.strip()

    if account_exists_with_same_data(
        db=db,
        user_id=user_id,
        name=clean_name,
        institution_name=clean_institution_name,
        account_type=account_type,
    ):
        raise ValueError("Account already exists")

    account = Account(
        user_id=user_id,
        name=clean_name,
        institution_name=clean_institution_name,
        account_type=account_type,
    )

    db.add(account)
    db.commit()
    db.refresh(account)

    return account


def update_account(
    db: Session,
    account: Account,
    data: dict,
) -> Account:
    new_name = data.get("name", account.name)
    new_institution_name = data.get("institution_name", account.institution_name)
    new_account_type = data.get("account_type", account.account_type)

    if account_exists_with_same_data(
        db=db,
        user_id=account.user_id,
        name=new_name,
        institution_name=new_institution_name,
        account_type=new_account_type,
        ignore_account_id=account.id,
    ):
        raise ValueError("Another account with the same data already exists")

    if data.get("name") is not None:
        account.name = data["name"].strip()

    if data.get("institution_name") is not None:
        account.institution_name = data["institution_name"].strip()

    if data.get("account_type") is not None:
        account.account_type = data["account_type"]

    db.add(account)
    db.commit()
    db.refresh(account)

    return account


def delete_account(db: Session, account: Account) -> None:
    db.delete(account)
    db.commit()