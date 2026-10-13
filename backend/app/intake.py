"""Read the owner's photos: menu → items and prices, shopfront → visibility, P&L → numbers."""

import statistics
from typing import Any, Dict, List, Optional, Tuple

from . import i18n, llm
from .schemas import Costs, MenuAnalysis, MenuItem, MonthValue, ShopfrontAnalysis

Upload = Tuple[str, str]  # (base64 data, media type)

_SYSTEM = (
    "You are the intake analyst for ShopDoctor, a consultant for Hong Kong small businesses. "
    "Photos may be in Traditional Chinese, English or both. Report only what you can see; "
    "use null for anything unreadable rather than guessing. Prices are in HKD."
)


def _system(lang: str) -> str:
    return _SYSTEM + " " + i18n.write_in(lang)


_MENU_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "price": {"type": ["number", "null"]},
                    "section": {"type": ["string", "null"]},
                },
                "required": ["name", "price", "section"],
                "additionalProperties": False,
            },
        },
        "clarity_score": {"type": "number", "description": "0-10"},
        "notes": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["items", "clarity_score", "notes"],
    "additionalProperties": False,
}

_SHOPFRONT_SCHEMA = {
    "type": "object",
    "properties": {
        "signage_score": {"type": "number"},
        "visibility_score": {"type": "number"},
        "condition_score": {"type": "number"},
        "appeal_score": {"type": "number"},
        "observations": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["signage_score", "visibility_score", "condition_score", "appeal_score", "observations"],
    "additionalProperties": False,
}

_NUM = {"type": ["number", "null"]}
_FINANCIALS_SCHEMA = {
    "type": "object",
    "properties": {
        "monthly_revenue": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"month": {"type": "string", "description": "YYYY-MM"}, "amount": {"type": "number"}},
                "required": ["month", "amount"],
                "additionalProperties": False,
            },
        },
        "rent": _NUM,
        "staff": _NUM,
        "ingredients": _NUM,
        "utilities": _NUM,
        "other": _NUM,
    },
    "required": ["monthly_revenue", "rent", "staff", "ingredients", "utilities", "other"],
    "additionalProperties": False,
}


def _summarise_menu(items: List[MenuItem], clarity: float, notes: List[str]) -> MenuAnalysis:
    prices = [i.price for i in items if i.price is not None and i.price > 0]
    return MenuAnalysis(
        items=items,
        item_count=len(items),
        avg_price=round(statistics.mean(prices), 1) if prices else None,
        median_price=statistics.median(prices) if prices else None,
        price_min=min(prices) if prices else None,
        price_max=max(prices) if prices else None,
        clarity_score=max(0.0, min(10.0, clarity)),
        notes=notes,
    )


async def analyse_menu(photos: List[Upload], lang: str = i18n.EN) -> Optional[MenuAnalysis]:
    if not photos:
        return None
    content: List[Dict[str, Any]] = [llm.image_block(d, t) for d, t in photos]
    content.append({
        "type": "text",
        "text": (
            "These are photos of one shop's menu. List every item with its price and menu section. "
            "Then score clarity 0-10 (legibility, logical sections, too many or too few choices) "
            "and add up to 4 short notes an owner could act on."
        ),
    })
    data = await llm.structured(system=_system(lang), content=content, schema=_MENU_SCHEMA, effort="low")
    items = [MenuItem(**i) for i in data["items"]]
    return _summarise_menu(items, data["clarity_score"], data["notes"])


async def analyse_shopfront(photos: List[Upload], lang: str = i18n.EN) -> Optional[ShopfrontAnalysis]:
    if not photos:
        return None
    content: List[Dict[str, Any]] = [llm.image_block(d, t) for d, t in photos]
    content.append({
        "type": "text",
        "text": (
            "These are photos of a Hong Kong shop's exterior. Score 0-10 each: signage (readable from "
            "across the street, bilingual, lit), visibility (sightline from foot traffic, not hidden "
            "upstairs or behind scaffolding), condition (paint, lighting, cleanliness), appeal (would a "
            "passer-by walk in). Give up to 5 concrete observations."
        ),
    })
    data = await llm.structured(system=_system(lang), content=content, schema=_SHOPFRONT_SCHEMA, effort="low")
    return ShopfrontAnalysis(**{k: (max(0.0, min(10.0, v)) if k.endswith("_score") else v) for k, v in data.items()})


async def read_financials(docs: List[Upload], lang: str = i18n.EN) -> Tuple[List[MonthValue], Optional[Costs]]:
    """Extract revenue history and monthly costs from a P&L / ledger photo or PDF."""
    if not docs:
        return [], None
    content: List[Dict[str, Any]] = [llm.image_block(d, t) for d, t in docs]
    content.append({
        "type": "text",
        "text": (
            "These are a small shop's revenue and cost records. Extract monthly revenue per month and "
            "the typical monthly cost for rent, staff, ingredients/stock, utilities and other. "
            "Convert to HKD per month."
        ),
    })
    data = await llm.structured(system=_system(lang), content=content, schema=_FINANCIALS_SCHEMA, effort="medium")
    revenue = [MonthValue(**m) for m in data["monthly_revenue"]]
    costs = Costs(**{k: data[k] or 0 for k in ("rent", "staff", "ingredients", "utilities", "other")})
    return revenue, costs
