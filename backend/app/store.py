"""JSON-file persistence — enough for an MVP; swap for a database later."""

import json
from pathlib import Path
from typing import Optional, Type, TypeVar

from pydantic import BaseModel

from . import config
from .schemas import Diagnosis, ExperienceAudit, ShopProfile

M = TypeVar("M", bound=BaseModel)


def _path(kind: str, shop_id: str) -> Path:
    if not shop_id.replace("-", "").isalnum():
        raise ValueError("bad id")
    return config.DATA_DIR / kind / f"{shop_id}.json"


def _save(kind: str, shop_id: str, model: BaseModel) -> None:
    path = _path(kind, shop_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(model.model_dump_json(indent=2))


def _load(kind: str, shop_id: str, cls: Type[M]) -> Optional[M]:
    path = _path(kind, shop_id)
    return cls.model_validate(json.loads(path.read_text())) if path.exists() else None


def save_shop(shop: ShopProfile) -> None:
    _save("shops", shop.id, shop)


def load_shop(shop_id: str) -> Optional[ShopProfile]:
    return _load("shops", shop_id, ShopProfile)


def save_diagnosis(d: Diagnosis) -> None:
    _save("diagnoses", d.shop_id, d)


def load_diagnosis(shop_id: str) -> Optional[Diagnosis]:
    return _load("diagnoses", shop_id, Diagnosis)


def save_experience(a: ExperienceAudit) -> None:
    _save("experience", a.shop_id, a)


def load_experience(shop_id: str) -> Optional[ExperienceAudit]:
    return _load("experience", shop_id, ExperienceAudit)
