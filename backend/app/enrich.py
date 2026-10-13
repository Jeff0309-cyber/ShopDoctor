"""Search the web for similar shops in the district that have closed.

Google Places drops many closed businesses entirely, so the closed group would
be thin without this pass. Claude uses server-side web search (OpenRice, news,
Facebook pages) and reports what it found through a strict custom tool.
"""

import hashlib
from typing import Any, Dict, List

from . import config, i18n, llm
from .schemas import ShopProfile, TwinShop
from .twins import haversine_m

_REPORT_TOOL = {
    "name": "report_closed_shops",
    "description": "Report the closed shops you found. Call exactly once when done searching.",
    "strict": True,
    "input_schema": {
        "type": "object",
        "properties": {
            "shops": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "address": {"type": ["string", "null"]},
                        "lat": {"type": ["number", "null"]},
                        "lng": {"type": ["number", "null"]},
                        "price_level": {"type": ["integer", "null"], "description": "0-4"},
                        "rating": {"type": ["number", "null"], "description": "0-5, last known"},
                        "closed_note": {"type": "string", "description": "When and, if reported, why it closed"},
                        "source_url": {"type": "string"},
                    },
                    "required": ["name", "address", "lat", "lng", "price_level", "rating", "closed_note", "source_url"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["shops"],
        "additionalProperties": False,
    },
}


async def find_closed_shops(shop: ShopProfile, known: List[TwinShop], lang: str = i18n.EN) -> List[TwinShop]:
    known_names = ", ".join(t.name for t in known if t.status != "survivor")[:2000] or "none"
    prompt = (
        f"Find {shop.category} businesses in or near {shop.district}, Hong Kong "
        f"(around {shop.address or shop.district}) that have permanently closed in the last five years. "
        "Check OpenRice listings marked closed (已結業), local news and social media. "
        f"Skip these, which are already known: {known_names}. "
        "Only report shops with a source that confirms the closure. Aim for up to 15. "
        "Then call report_closed_shops once with what you found. "
        + ("Write each closed_note in Traditional Chinese (書面語)." if lang == i18n.ZH else "Write each closed_note in English.")
    )
    messages: List[Dict[str, Any]] = [{"role": "user", "content": prompt}]
    tools = [
        {"type": "web_search_20260209", "name": "web_search", "max_uses": 8,
         "user_location": {"type": "approximate", "country": "HK", "city": "Hong Kong"}},
        _REPORT_TOOL,
    ]

    for _ in range(4):
        response = await llm.client().beta.messages.create(
            model=config.MODEL,
            max_tokens=16000,
            messages=messages,
            tools=tools,
            output_config={"effort": "medium"},
            **llm.FALLBACK_KWARGS,
        )
        report = next((b for b in response.content if b.type == "tool_use" and b.name == "report_closed_shops"), None)
        if report is not None:
            return [_to_twin(s, shop) for s in report.input.get("shops", []) if isinstance(s, dict) and s.get("name")]
        if response.stop_reason in ("refusal", "max_tokens"):
            break
        messages.append({"role": "assistant", "content": response.content})
        if response.stop_reason != "pause_turn":
            messages.append({"role": "user", "content": "Call report_closed_shops now with what you found."})
    return []


def _to_twin(s: Dict[str, Any], shop: ShopProfile) -> TwinShop:
    has_loc = s.get("lat") is not None and s.get("lng") is not None
    return TwinShop(
        id="web-" + hashlib.sha1(s["name"].encode()).hexdigest()[:12],
        name=s["name"],
        address=s.get("address"),
        lat=s.get("lat"),
        lng=s.get("lng"),
        status="closed",
        source="web",
        rating=s.get("rating"),
        price_level=s.get("price_level"),
        distance_m=round(haversine_m(shop.lat, shop.lng, s["lat"], s["lng"])) if has_loc else None,
        closed_note=s.get("closed_note"),
        source_url=s.get("source_url"),
    )
