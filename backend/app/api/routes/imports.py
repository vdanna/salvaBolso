from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.database import get_db
from app.db.models import User
from app.modules.accounts.service import get_account_by_id
from app.modules.imports.account_csv import (
    build_preview_summary,
    process_account_csv,
    save_account_csv_transactions,
)
from app.schemas.imports import AccountCsvImportResponse, AccountCsvPreviewResponse, CreditCardCsvImportResponse, CreditCardCsvPreviewResponse

from app.modules.imports.credit_card_csv import (
    build_credit_card_preview_summary,
    process_credit_card_csv,
    save_credit_card_csv_transactions,
)


router = APIRouter(prefix="/imports", tags=["imports"])


async def read_uploaded_csv(file: UploadFile) -> bytes:
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Arquivo sem nome.",
        )

    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="O arquivo enviado precisa ser um CSV.",
        )

    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="O arquivo CSV está vazio.",
        )

    return content


def validate_account_for_account_csv(
    db: Session,
    user_id: int,
    account_id: int,
) -> None:
    account = get_account_by_id(
        db=db,
        user_id=user_id,
        account_id=account_id,
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conta não encontrada.",
        )

    if account.account_type != "checking":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="CSV de conta corrente só pode ser importado para uma conta do tipo checking.",
        )


@router.post(
    "/account-csv/preview",
    response_model=AccountCsvPreviewResponse,
)
async def preview_account_csv_import(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    account_id: Annotated[int, Form()],
    file: Annotated[UploadFile, File()],
) -> dict:
    validate_account_for_account_csv(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    content = await read_uploaded_csv(file)

    try:
        processed = process_account_csv(
            file_name=file.filename or "arquivo.csv",
            content=content,
            account_id=account_id,
        )

        return build_preview_summary(processed)

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.post(
    "/account-csv",
    response_model=AccountCsvImportResponse,
    status_code=status.HTTP_201_CREATED,
)
async def import_account_csv(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    account_id: Annotated[int, Form()],
    file: Annotated[UploadFile, File()],
) -> dict:
    validate_account_for_account_csv(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    content = await read_uploaded_csv(file)

    try:
        processed = process_account_csv(
            file_name=file.filename or "arquivo.csv",
            content=content,
            account_id=account_id,
        )

        result = save_account_csv_transactions(
            db=db,
            user_id=current_user.id,
            account_id=account_id,
            processed=processed,
        )

        import_batch = result["import_batch"]

        return {
            "success": True,
            "import_batch_id": import_batch.id,
            "file_name": import_batch.file_name,
            "format": import_batch.source_format,
            "period_start": import_batch.period_start,
            "period_end": import_batch.period_end,
            "total_rows": import_batch.total_rows,
            "imported": result["imported"],
            "duplicates": result["duplicates"],
            "errors": processed.errors,
            "warnings": processed.warnings,
        }

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT
            if "já foi importado" in str(error)
            else status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    
def validate_account_for_credit_card_csv(
    db: Session,
    user_id: int,
    account_id: int,
) -> None:
    account = get_account_by_id(
        db=db,
        user_id=user_id,
        account_id=account_id,
    )

    if account is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conta não encontrada.",
        )

    if account.account_type != "credit_card":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="CSV de fatura só pode ser importado para uma conta do tipo credit_card.",
        )


@router.post(
    "/credit-card-csv/preview",
    response_model=CreditCardCsvPreviewResponse,
)
async def preview_credit_card_csv_import(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    account_id: Annotated[int, Form()],
    file: Annotated[UploadFile, File()],
) -> dict:
    validate_account_for_credit_card_csv(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    content = await read_uploaded_csv(file)

    try:
        processed = process_credit_card_csv(
            file_name=file.filename or "arquivo.csv",
            content=content,
            account_id=account_id,
        )

        return build_credit_card_preview_summary(processed)

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.post(
    "/credit-card-csv",
    response_model=CreditCardCsvImportResponse,
    status_code=status.HTTP_201_CREATED,
)
async def import_credit_card_csv(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    account_id: Annotated[int, Form()],
    file: Annotated[UploadFile, File()],
) -> dict:
    validate_account_for_credit_card_csv(
        db=db,
        user_id=current_user.id,
        account_id=account_id,
    )

    content = await read_uploaded_csv(file)

    try:
        processed = process_credit_card_csv(
            file_name=file.filename or "arquivo.csv",
            content=content,
            account_id=account_id,
        )

        result = save_credit_card_csv_transactions(
            db=db,
            user_id=current_user.id,
            account_id=account_id,
            processed=processed,
        )

        import_batch = result["import_batch"]
        statement = result["statement"]

        return {
            "success": True,
            "statement_id": statement.id,
            "import_batch_id": import_batch.id,
            "file_name": import_batch.file_name,
            "format": import_batch.source_format,
            "period_start": import_batch.period_start,
            "period_end": import_batch.period_end,
            "due_date": statement.due_date,
            "statement_reference": statement.statement_reference,
            "total_rows": import_batch.total_rows,
            "imported": result["imported"],
            "duplicates": result["duplicates"],
            "purchase_rows": processed.purchase_rows,
            "payment_rows": processed.payment_rows,
            "installment_rows": processed.installment_rows,
            "matched_payments": result["matched_payments"],
            "pending_payments": result["pending_payments"],
            "errors": processed.errors,
            "warnings": processed.warnings,
        }

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT
            if "já foi importado" in str(error)
            else status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error