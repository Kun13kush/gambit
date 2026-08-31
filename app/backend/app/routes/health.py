from datetime import datetime

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
def health():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
    }


@router.get("/info")
def info():
    return {
        "application": "production-aws-platform",
        "version": "1.0.0",
        "environment": "development",
    }