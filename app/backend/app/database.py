import os
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker


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
            f"Missing required production database configuration: "
            f"{', '.join(missing)}"
        )

    DATABASE_URL = (
        f"postgresql://{quote_plus(db_username)}:"
        f"{quote_plus(db_password)}@"
        f"{db_host}:{db_port}/{db_name}"
    )
else:
    DATABASE_URL = os.getenv(
        "DATABASE_URL",
        "postgresql://platform:platform@localhost:5432/platform",
    )


engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()