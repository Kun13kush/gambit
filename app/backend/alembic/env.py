from logging.config import fileConfig
import os
from urllib.parse import quote_plus

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

from app.database import Base
from app import models


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)


def get_database_url():
    environment = os.getenv("ENVIRONMENT", "development")

    if environment == "production":
        db_host = os.getenv("DB_HOST")
        db_port = os.getenv("DB_PORT", "5432")
        db_name = os.getenv("DB_NAME")
        db_username = os.getenv("DB_USERNAME")
        db_password = os.getenv("DB_PASSWORD")

        required = {
            "DB_HOST": db_host,
            "DB_NAME": db_name,
            "DB_USERNAME": db_username,
            "DB_PASSWORD": db_password,
        }

        missing = [name for name, value in required.items() if not value]

        if missing:
            raise RuntimeError(
                "Missing required production database configuration: "
                + ", ".join(missing)
            )

        return (
            f"postgresql://{quote_plus(db_username)}:"
            f"{quote_plus(db_password)}@"
            f"{db_host}:{db_port}/{db_name}"
        )

    return os.getenv(
        "DATABASE_URL",
        "postgresql://platform:platform@localhost:5432/platform",
    )


config.set_main_option(
    "sqlalchemy.url",
    get_database_url().replace("%", "%%"),
)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")

    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
