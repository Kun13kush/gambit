from datetime import UTC, datetime

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
def health():
    return {
        "status": "healthy",
        "timestamp": datetime.now(UTC).isoformat(),
    }


@router.get("/info")
def info():
    return {
        "application": "production-aws-platform",
        "version": "1.0.0",
        "environment": "development",
    }