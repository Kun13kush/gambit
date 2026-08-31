from datetime import datetime, timedelta

from app.database import SessionLocal
from app.models import Deployment, Service


def seed():
    db = SessionLocal()

    try:
        if db.query(Service).count() > 0:
            print("Database already contains data.")
            return

        services = [
            Service(
                name="Frontend",
                status="healthy",
                version="1.0.0",
            ),
            Service(
                name="Backend API",
                status="healthy",
                version="1.0.0",
            ),
            Service(
                name="PostgreSQL",
                status="healthy",
                version="16",
            ),
            Service(
                name="Redis",
                status="healthy",
                version="7",
            ),
        ]

        deployments = [
            Deployment(
                service="Backend API",
                version="1.0.0",
                status="successful",
                deployed_at=datetime.utcnow(),
            ),
            Deployment(
                service="Frontend",
                version="1.0.0",
                status="successful",
                deployed_at=datetime.utcnow() - timedelta(hours=2),
            ),
            Deployment(
                service="Backend API",
                version="0.9.0",
                status="rolled_back",
                deployed_at=datetime.utcnow() - timedelta(days=1),
            ),
        ]

        db.add_all(services)
        db.add_all(deployments)

        db.commit()

        print("Database seeded successfully.")

    finally:
        db.close()


if __name__ == "__main__":
    seed()