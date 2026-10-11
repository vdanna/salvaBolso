from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import Account, User
from app.modules.accounts.service import (
    create_account,
    delete_account,
    get_account_by_id,
    get_accounts,
    update_account,
)
from app.schemas.accounts import AccountCreate, AccountRead, AccountUpdate


router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.post(
    "",
    response_model=AccountRead,
    status_code=status.HTTP_201_CREATED,
)
def create_account_endpoint(
    payload: AccountCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Account:
    try:
        return create_account(
            db=db,
            user_id=current_user.id,
            name=payload.name,
            institution_name=payload.institution_name,
            account_type=payload.account_type,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error


@router.get("", response_model=list[AccountRead])
def list_accounts_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> list[Account]:
    return get_accounts(
        db=db,
        user_id=current_user.id,
    )


@router.get("/{account_id}", response_model=AccountRead)
def get_account_endpoint(
    account_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Account:
    account = get_account_by_id(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    return account


@router.put("/{account_id}", response_model=AccountRead)
def update_account_endpoint(
    account_id: int,
    payload: AccountUpdate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> Account:
    account = get_account_by_id(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    update_data = payload.model_dump(exclude_unset=True)

    try:
        return update_account(
            db=db,
            account=account,
            data=update_data,
        )

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error


@router.delete("/{account_id}", status_code=status.HTTP_200_OK)
def delete_account_endpoint(
    account_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict:
    account = get_account_by_id(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found",
        )

    delete_account(db=db, account=account)

    return {
        "success": True,
        "message": "Account deleted successfully",
    }