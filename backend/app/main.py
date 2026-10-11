from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes.accounts import router as accounts_router
from app.api.routes.auth import router as auth_router
from app.api.routes.chat import router as chat_router
from app.api.routes.health import router as health_router
from app.api.routes.imports import router as imports_router
from app.api.routes.reconciliation import router as reconciliation_router
from app.api.routes.summaries import router as summaries_router
from app.core.config import get_settings
from app.api.routes.credit_card_statements import router as credit_card_statements_router
from app.api.routes.transactions import router as transactions_router
from app.api.routes.categories import router as categories_router


settings = get_settings()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["root"])
def root() -> dict:
    return {
        "message": "Personal Finance API is running",
        "docs": "/docs",
        "health": f"{settings.api_prefix}/health",
    }


app.include_router(health_router, prefix=settings.api_prefix)
app.include_router(auth_router, prefix=settings.api_prefix)
app.include_router(accounts_router, prefix=settings.api_prefix)
app.include_router(imports_router, prefix=settings.api_prefix)
app.include_router(reconciliation_router, prefix=settings.api_prefix)
app.include_router(summaries_router, prefix=settings.api_prefix)
app.include_router(chat_router, prefix=settings.api_prefix)
app.include_router(credit_card_statements_router, prefix=settings.api_prefix)
app.include_router(transactions_router, prefix=settings.api_prefix)
app.include_router(categories_router, prefix=settings.api_prefix)