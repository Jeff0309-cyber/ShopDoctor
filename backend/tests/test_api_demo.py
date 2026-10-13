"""End-to-end API flow in demo mode (no external calls)."""

import json

import pytest
from fastapi.testclient import TestClient

from app import config


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DEMO_MODE", True)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    from app.main import app
    return TestClient(app)


SHOP = {
    "name": "Wing Kee Café", "category": "cha chaan teng", "district": "Mong Kok",
    "lat": 22.3193, "lng": 114.1694, "weekly_hours": 63,
    "monthly_revenue": [{"month": "2026-07", "amount": 171000}, {"month": "2026-08", "amount": 165000},
                        {"month": "2026-09", "amount": 160000}],
    "costs": {"rent": 48000, "staff": 55000, "ingredients": 52000, "utilities": 8000, "other": 4000},
}


def test_full_flow(client):
    r = client.post("/v1/shops", data={"shop": json.dumps(SHOP)},
                    files=[("menu_photos", ("menu.jpg", b"\xff\xd8fake", "image/jpeg"))])
    assert r.status_code == 200, r.text
    shop = r.json()
    assert shop["menu"]["item_count"] == 86
    assert shop["shopfront"] is None

    d = client.post(f"/v1/shops/{shop['id']}/diagnose").json()
    assert 0 <= d["health"]["overall"] <= 100
    assert d["comparison"]["closed_count"] > 0
    assert len([p for p in d["forecast"]["points"] if not p["is_actual"]]) == 12
    assert d["prescriptions"]
    assert any("Demo mode" in n for n in d["data_notes"])

    assert client.get(f"/v1/shops/{shop['id']}/diagnosis").json()["shop_id"] == shop["id"]

    with client.stream("POST", f"/v1/shops/{shop['id']}/doctor",
                       json={"messages": [{"role": "user", "content": "How am I doing?"}]}) as s:
        events = [json.loads(line[6:]) for line in s.iter_lines() if line.startswith("data: ")]
    assert events[-1] == {"type": "done"}
    assert "Health Score" in "".join(e.get("text", "") for e in events)


def test_rejects_bad_upload_and_unknown_shop(client):
    r = client.post("/v1/shops", data={"shop": json.dumps(SHOP)},
                    files=[("menu_photos", ("menu.txt", b"hi", "text/plain"))])
    assert r.status_code == 415
    assert client.get("/v1/shops/nope").status_code == 404
    assert client.get("/v1/shops/..%2Fetc").status_code == 404
