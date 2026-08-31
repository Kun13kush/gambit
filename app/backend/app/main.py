import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routes import deployments, health, services

app = FastAPI(
    title="Production AWS Platform API",
    version="1.0.0",
)

frontend_url = os.getenv(
    "FRONTEND_URL",
    "http://localhost:5173",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[frontend_url],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


Base.metadata.create_all(bind=engine)


app.include_router(health.router)
app.include_router(services.router)
app.include_router(deployments.router)


@app.get("/")
def root():
    return {
        "application": "production-aws-platform",
        "status": "running",
    }