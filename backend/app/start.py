import os
import time

import uvicorn
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

from app.core.config import get_settings


def wait_for_database(max_attempts: int = 30, delay_seconds: int = 2) -> None:
    settings = get_settings()

    print("Aguardando PostgreSQL ficar disponível...")

    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,
    )

    try:
        for attempt in range(1, max_attempts + 1):
            try:
                with engine.connect() as connection:
                    connection.execute(text("SELECT 1"))

                print("PostgreSQL disponível.")
                return

            except OperationalError:
                print(
                    f"Banco ainda indisponível. "
                    f"Tentativa {attempt}/{max_attempts}..."
                )
                time.sleep(delay_seconds)

        raise RuntimeError(
            "PostgreSQL não ficou disponível dentro do tempo esperado."
        )

    finally:
        engine.dispose()


def run_migrations() -> None:
    print("Rodando migrações Alembic...")

    alembic_config = Config("alembic.ini")
    command.upgrade(alembic_config, "head")

    print("Migrações concluídas.")


def start_api() -> None:
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))

    print(f"Iniciando FastAPI em {host}:{port}...")

    uvicorn.run(
        "app.main:app",
        host=host,
        port=port,
        reload=False,
    )


if __name__ == "__main__":
    wait_for_database()
    run_migrations()
    start_api()