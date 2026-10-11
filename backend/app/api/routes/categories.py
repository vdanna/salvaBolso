from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import User
from app.modules.categories.service import (
    bootstrap_default_categories,
    bootstrap_default_rules,
    categorize_uncategorized_transactions,
    create_category,
    create_category_rule,
    get_category,
    list_categories,
    list_category_rules,
    replace_and_delete_category,
)
from app.schemas.categories import (
    CategorizeTransactionsResponse,
    CategoryCreate,
    CategoryRead,
    CategoryRuleCreate,
    CategoryRuleRead,
    ReplaceCategoryRequest,
)


router = APIRouter(
    prefix="/categories",
    tags=["categories"],
)


@router.post("/bootstrap", response_model=list[CategoryRead])
def bootstrap_categories_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    categories = bootstrap_default_categories(
        db=db,
        user_id=current_user.id,
    )

    bootstrap_default_rules(
        db=db,
        user_id=current_user.id,
    )

    return categories


@router.get("", response_model=list[CategoryRead])
def list_categories_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    classification: str | None = Query(default=None),
    roots_only: bool = Query(default=False),
):
    return list_categories(
        db=db,
        user_id=current_user.id,
        classification=classification,
        roots_only=roots_only,
    )


@router.post("", response_model=CategoryRead, status_code=status.HTTP_201_CREATED)
def create_category_endpoint(
    payload: CategoryCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    try:
        return create_category(
            db=db,
            user_id=current_user.id,
            name=payload.name,
            color=payload.color,
            lucide_icon=payload.lucide_icon,
            classification=payload.classification,
            parent_id=payload.parent_id,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get("/{category_id}", response_model=CategoryRead)
def get_category_endpoint(
    category_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    category = get_category(
        db=db,
        user_id=current_user.id,
        category_id=category_id,
    )

    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Categoria não encontrada.",
        )

    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category_endpoint(
    category_id: int,
    payload: ReplaceCategoryRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    try:
        replace_and_delete_category(
            db=db,
            user_id=current_user.id,
            category_id=category_id,
            replacement_category_id=payload.replacement_category_id,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.get("/rules/list", response_model=list[CategoryRuleRead])
def list_rules_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return list_category_rules(
        db=db,
        user_id=current_user.id,
    )


@router.post(
    "/rules",
    response_model=CategoryRuleRead,
    status_code=status.HTTP_201_CREATED,
)
def create_rule_endpoint(
    payload: CategoryRuleCreate,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    try:
        return create_category_rule(
            db=db,
            user_id=current_user.id,
            category_id=payload.category_id,
            pattern=payload.pattern,
            match_type=payload.match_type,
            field=payload.field,
            priority=payload.priority,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.post(
    "/categorize-transactions",
    response_model=CategorizeTransactionsResponse,
)
def categorize_transactions_endpoint(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    return categorize_uncategorized_transactions(
        db=db,
        user_id=current_user.id,
    )