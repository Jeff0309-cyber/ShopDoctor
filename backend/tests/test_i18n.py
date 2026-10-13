import json
import re
import string

import pytest
from fastapi.testclient import TestClient

from app import config, i18n
from tests.test_api_demo import SHOP

CJK = re.compile(r"[一-鿿]")


def is_chinese(text: str) -> bool:
    return bool(CJK.search(text))


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DEMO_MODE", True)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    from app.main import app
    return TestClient(app)


def test_every_template_has_both_languages_with_same_placeholders():
    fields = lambda s: {f for _, f, _, _ in string.Formatter().parse(s) if f}
    for key, (en, zh) in i18n._T.items():
        assert en and zh, key
        assert is_chinese(zh), key
        assert fields(en) == fields(zh), key


def test_norm_accept_language():
    assert i18n.norm("zh-Hant-HK") == i18n.ZH
    assert i18n.norm("zh-HK,en;q=0.8") == i18n.ZH
    assert i18n.norm("en-GB") == i18n.EN
    assert i18n.norm(None) == i18n.EN


def test_chinese_flow_end_to_end(client):
    zh = {"Accept-Language": "zh-Hant-HK"}
    shop = client.post("/v1/shops", data={"shop": json.dumps(SHOP)}, headers=zh,
                       files=[("menu_photos", ("m.jpg", b"x", "image/jpeg"))]).json()
    assert shop["lang"] == "zh-HK"
    assert is_chinese(shop["menu"]["notes"][0])

    d = client.post(f"/v1/shops/{shop['id']}/diagnose", headers=zh).json()
    assert all(is_chinese(s["label"]) and is_chinese(s["explanation"]) for s in d["health"]["subscores"])
    assert all(is_chinese(f["message"]) for f in d["comparison"]["findings"])
    assert all(is_chinese(a) for a in d["forecast"]["assumptions"])
    assert all(is_chinese(n) for n in d["data_notes"])
    assert all(is_chinese(p["title"]) for p in d["prescriptions"])
    assert all(is_chinese(c["category"]) for c in d["financials"]["cost_breakdown"])

    with client.stream("POST", f"/v1/shops/{shop['id']}/doctor", headers=zh,
                       json={"messages": [{"role": "user", "content": "我的店舖情況如何？"}]}) as s:
        text = "".join(json.loads(l[6:]).get("text", "") for l in s.iter_lines() if l.startswith("data: "))
    assert "健康評分" in text


def test_switching_back_to_english_rewrites_text(client):
    shop = client.post("/v1/shops", data={"shop": json.dumps(SHOP)}, headers={"Accept-Language": "zh-HK"}).json()
    d = client.post(f"/v1/shops/{shop['id']}/diagnose", headers={"Accept-Language": "en"}).json()
    assert not any(is_chinese(s["explanation"]) for s in d["health"]["subscores"])
    assert client.get(f"/v1/shops/{shop['id']}").json()["lang"] == "en"
