from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Service
from ..schemas import ServiceResponse

router = APIRouter(
    prefix="/api/services",
    tags=["services"],
)


@router.get("", response_model=list[ServiceResponse])
def get_services(
    db: Session = Depends(get_db),
):
    return db.query(Service).all()