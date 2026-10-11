from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Personal Finance API"
    app_env: str = "development"
    app_version: str = "0.1.0"

    api_prefix: str = "/api"
    debug: bool = True

    allowed_origins: str = (
        "http://localhost:3000,"
        "http://localhost:5173,"
        "http://127.0.0.1:8000"
    )

    postgres_user: str = "finance_user"
    postgres_password: str = "finance_password"
    postgres_db: str = "finance_db"
    postgres_port: str = "5432"

    database_url: str = (
        "postgresql+psycopg://finance_user:"
        "finance_password@localhost:5432/finance_db"
    )

    jwt_secret_key: str = "change_me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440

    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def allowed_origins_list(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()