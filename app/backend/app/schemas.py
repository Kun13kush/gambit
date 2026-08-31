from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ServiceResponse(BaseModel):
    id: int
    name: str
    status: str
    version: str

    model_config = ConfigDict(from_attributes=True)


class DeploymentResponse(BaseModel):
    id: int
    service: str
    version: str
    status: str
    deployed_at: datetime

    model_config = ConfigDict(from_attributes=True)