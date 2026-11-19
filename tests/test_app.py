from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz_returns_ok():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_readyz_reports_uptime():
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["ready"] is True
    assert response.json()["uptime_seconds"] >= 0


def test_celsius_to_fahrenheit():
    response = client.post("/v1/convert", json={"value": 100.0, "unit": "c"})
    assert response.status_code == 200
    assert response.json()["converted"] == 212.0
    assert response.json()["converted_unit"] == "F"


def test_fahrenheit_to_celsius():
    response = client.post("/v1/convert", json={"value": 32.0, "unit": "f"})
    assert response.status_code == 200
    assert response.json()["converted"] == 0.0


def test_unsupported_unit_rejected():
    response = client.post("/v1/convert", json={"value": 10.0, "unit": "k"})
    assert response.status_code == 422


def test_value_above_bound_rejected():
    response = client.post("/v1/convert", json={"value": 99999.0, "unit": "c"})
    assert response.status_code == 422


def test_missing_field_rejected():
    response = client.post("/v1/convert", json={"value": 10.0})
    assert response.status_code == 422


def test_malformed_payload_rejected():
    response = client.post("/v1/convert", json={"value": "hot", "unit": "c"})
    assert response.status_code == 422


def test_unknown_route_returns_404():
    response = client.get("/v1/does-not-exist")
    assert response.status_code == 404
