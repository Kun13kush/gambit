import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routes import deployments, health, services

environment = os.getenv("ENVIRONMENT", "development")

app = FastAPI(
    title="Production AWS Platform API",
    version="1.0.0",
    docs_url=None if environment == "production" else "/docs",
    redoc_url=None if environment == "production" else "/redoc",
    openapi_url=None if environment == "production" else "/openapi.json",
)

frontend_url = os.getenv(
    "FRONTEND_URL",
    "http://localhost:5173",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[frontend_url],
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["Accept"],
)



app.include_router(health.router)
app.include_router(services.router)
app.include_router(deployments.router)


@app.get("/")
def root():
    return {
        "application": "production-aws-platform",
        "status": "running",
    }