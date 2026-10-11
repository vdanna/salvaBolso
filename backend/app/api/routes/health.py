from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core.config import get_settings
from app.db.database import SessionLocal

router = APIRouter(prefix="/health", tags=["health"])


@router.get("")
def health_check() -> dict:
    settings = get_settings()

    return {
        "status": "ok",
        "app_name": settings.app_name,
        "environment": settings.app_env,
        "version": settings.app_version,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/database")
def database_health_check() -> dict:
    try:
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))

        return {
            "database": "connected",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    except SQLAlchemyError as error:
        raise HTTPException(
            status_code=503,
            detail={
                "database": "unavailable",
                "error": str(error),
            },
        ) from error