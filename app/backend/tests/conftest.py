import os
import time

import pytest
from sqlalchemy import create_engine, text


@pytest.fixture(scope="session", autouse=True)
def wait_for_database():
    """Wait for database to be ready before running tests."""
    database_url = os.getenv(
        "DATABASE_URL",
        "postgresql://platform:platform@localhost:5432/platform",
    )

    max_retries = 30
    retry_count = 0

    while retry_count < max_retries:
        try:
            engine = create_engine(database_url)

            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))

            print("✓ Database is ready")
            return

        except Exception:
            retry_count += 1
            print(
                f"Waiting for database... "
                f"(attempt {retry_count}/{max_retries})"
            )
            time.sleep(1)

    raise RuntimeError(
        "Database failed to become available after 30 seconds"
    )