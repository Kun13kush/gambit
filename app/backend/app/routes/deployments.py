from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Deployment
from ..schemas import DeploymentResponse

router = APIRouter(
    prefix="/api/deployments",
    tags=["deployments"],
)


@router.get("", response_model=list[DeploymentResponse])
def get_deployments(
    db: Session = Depends(get_db),
):
    return (
        db.query(Deployment)
        .order_by(Deployment.deployed_at.desc())
        .all()
    )