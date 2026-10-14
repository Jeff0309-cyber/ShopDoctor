"""The public website is served from the API, and AI-backed requests are rate limited."""

import json

from fastapi.testclient import TestClient

from app import config, ratelimit
from tests.test_api_demo import SHOP


def test_website_is_served():
    from app.main import app
    c = TestClient(app)
    home = c.get("/")
    assert home.status_code == 200 and "ShopDoctor" in home.text
    assert c.get("/js/app.js").status_code == 200
    zh = c.get("/i18n/zh-HK.json").json()
    assert zh["Run diagnosis"] == "開始診斷"
    assert c.get("/health").json()["ok"] is True  # API routes still win over the static mount


def test_ai_requests_are_rate_limited_per_visitor(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DEMO_MODE", False)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    monkeypatch.setattr(config, "AI_REQUESTS_PER_HOUR", 2)
    ratelimit._per_ip.clear()
    ratelimit._all.clear()
    from app.main import app
    c = TestClient(app)
    visitor = {"X-Forwarded-For": "203.0.113.7"}
    for _ in range(2):  # no photos, so these don't call the AI, but they still count
        assert c.post("/v1/shops", data={"shop": json.dumps(SHOP)}, headers=visitor).status_code == 200
    blocked = c.post("/v1/shops", data={"shop": json.dumps(SHOP)}, headers=visitor)
    assert blocked.status_code == 429
    # Another visitor is unaffected, and non-AI requests are never limited.
    assert c.post("/v1/shops", data={"shop": json.dumps(SHOP)}, headers={"X-Forwarded-For": "198.51.100.2"}).status_code == 200
    assert c.get("/health", headers=visitor).status_code == 200
