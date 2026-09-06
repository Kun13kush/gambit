from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_root():
    response = client.get("/")

    assert response.status_code == 200

    data = response.json()

    assert data["application"] == "production-aws-platform"
    assert data["status"] == "running"


def test_health():
    response = client.get("/health")

    assert response.status_code == 200

    data = response.json()

    assert data["status"] == "healthy"
    assert "timestamp" in data


def test_info():
    response = client.get("/info")

    assert response.status_code == 200

    data = response.json()

    assert data["application"] == "production-aws-platform"
    assert data["version"] == "1.0.0"
    assert data["environment"] == "development"
