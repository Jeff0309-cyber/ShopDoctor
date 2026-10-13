import json

import pytest
from fastapi.testclient import TestClient

from app import config, demo, experience
from app.schemas import ExperienceAudit, ExperienceIssue, SuggestedMove
from tests.test_api_demo import SHOP
from tests.test_i18n import is_chinese

JPEG = ("x.jpg", b"\xff\xd8fake", "image/jpeg")


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DEMO_MODE", True)
    monkeypatch.setattr(config, "DATA_DIR", tmp_path)
    from app.main import app
    c = TestClient(app)
    c.shop_id = c.post("/v1/shops", data={"shop": json.dumps(SHOP)}).json()["id"]
    return c


def test_scan_flow_stores_and_returns_audit(client):
    room = demo.sample_room().model_dump_json()
    r = client.post(f"/v1/shops/{client.shop_id}/experience", data={"room": room},
                    files=[("shot_entrance", JPEG), ("shot_table", JPEG), ("shot_ordering", JPEG)])
    assert r.status_code == 200, r.text
    audit = r.json()
    assert audit["layout"]["narrowest_aisle_m"] == 0.3
    assert [i["id"] for i in audit["issues"]] == [f"issue-{n}" for n in range(1, len(audit["issues"]) + 1)]
    moves = {i["target"]: i["suggested_move"] for i in audit["issues"] if i["suggested_move"]}
    assert set(moves) == {"rack", "table-6"}
    assert client.get(f"/v1/shops/{client.shop_id}/experience").json()["overall"] == audit["overall"]

    # The diagnosis now blends the experience score into visibility.
    d = client.post(f"/v1/shops/{client.shop_id}/diagnose").json()
    vis = next(s for s in d["health"]["subscores"] if s["key"] == "visibility")
    assert "experience" in vis["explanation"].lower()


def test_photo_only_flow_requires_four_shots(client):
    url = f"/v1/shops/{client.shop_id}/experience"
    r = client.post(url, files=[("shot_entrance", JPEG), ("shot_table", JPEG)])
    assert r.status_code == 422
    assert set(r.json()["detail"]["missing_shots"]) == {"door", "seating"}

    r = client.post(url, files=[(f"shot_{s}", JPEG) for s in ("entrance", "door", "seating", "table")])
    audit = r.json()
    assert audit["room"] is None
    assert all(i["target"] is None or i["target"].startswith("photo:") for i in audit["issues"])


def test_rejects_unknown_shot_and_bad_room(client):
    url = f"/v1/shops/{client.shop_id}/experience"
    assert client.post(url, files=[("shot_kitchen_ceiling", JPEG)]).status_code == 422
    assert client.post(url, data={"room": "{not json"}, files=[("shot_entrance", JPEG)]).status_code == 422


def test_chinese_audit(client):
    r = client.post(f"/v1/shops/{client.shop_id}/experience", headers={"Accept-Language": "zh-HK"},
                    data={"room": demo.sample_room().model_dump_json()},
                    files=[("shot_entrance", JPEG), ("shot_table", JPEG)])
    audit = r.json()
    assert is_chinese(audit["verdict"]) and all(is_chinese(i["title"]) for i in audit["issues"])


def test_finalise_drops_invented_targets_and_invalid_moves():
    issue = lambda **kw: ExperienceIssue(id="", area="flow", title="t", observation="o", why_it_matters="w",
                                         steps=["s"], cost="low", effort="1h", impact="low", **kw)
    audit = ExperienceAudit(
        shop_id="x", overall=140, verdict="v", areas=[], room=demo.sample_room(), shots=["entrance"],
        issues=[
            issue(target="table-99"),
            issue(target="photo:washroom"),  # no washroom photo was taken
            issue(target="table-6", suggested_move=SuggestedMove(object_id="table-6", dx_m=-1.05, dz_m=0)),
            issue(target="photo:entrance"),
        ],
    )
    out = experience.finalise(audit)
    assert out.overall == 100
    assert [i.target for i in out.issues] == [None, None, "table-6", "photo:entrance"]
    assert out.issues[2].suggested_move is None
