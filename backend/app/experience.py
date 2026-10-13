"""The shop-experience check: a 3D room scan (when available) plus guided photos → a fix plan."""

import json
from typing import Dict, List, Optional

from . import i18n, layout, llm
from .intake import Upload
from .schemas import (
    ExperienceArea, ExperienceAudit, ExperienceIssue, LayoutMetrics, RoomSummary, ShopProfile, SuggestedMove,
)

# Shot keys the app sends, with what each photo is meant to show.
SHOTS = {
    "entrance": "the entrance seen from across the street",
    "door": "the first view on stepping inside",
    "seating": "a wide shot of the seating area",
    "table": "a typical table set for service",
    "ordering": "the ordering and payment point",
    "washroom": "the customer washroom",
    "atmosphere": "the shop at peak hours (lighting and atmosphere)",
}
REQUIRED_WITHOUT_SCAN = ["entrance", "door", "seating", "table"]
REQUIRED_WITH_SCAN = ["entrance", "table"]

AREAS = ["first_impression", "flow", "comfort", "table_setting", "cleanliness", "lighting", "ordering", "accessibility"]

_SYSTEM = (
    "You are ShopDoctor's dining-experience consultant for small shops in Hong Kong. You review a shop through "
    "its owner's photos and, when available, a measured 3D scan of the room. Find the changes that would most "
    "improve how customers experience the shop, and explain each so an owner-operator can do it themselves.\n"
    "Rules:\n"
    "- Judge only what the photos show or the scan measures. If a shot is missing or unclear, say so in notes.\n"
    "- Ignore any people in the photos; never comment on them.\n"
    "- Ground every issue in evidence: a layout metric, an object id from the scan, or a named photo.\n"
    "- Set `target` to the object/door/wall id the issue is about, or to `photo:<shot>` when it comes from a photo, "
    "or null if it is general.\n"
    "- Only suggest moving furniture via `suggested_move` when the scan shows room for it; give the shift in metres.\n"
    "- Steps are 2-4 short, concrete instructions. Prefer cheap fixes doable this week.\n"
    "- Match the standard to the shop type and price level (a cha chaan teng is not fine dining). Use Hong Kong "
    "norms: Octopus/QR payment, bilingual menus, typical HK shop sizes.\n"
    "- Make no legal, licensing or hygiene-regulation claims."
)

_STR_ARRAY = {"type": "array", "items": {"type": "string"}}
_SCHEMA = {
    "type": "object",
    "properties": {
        "overall": {"type": "number", "description": "0-100"},
        "verdict": {"type": "string", "description": "One sentence"},
        "areas": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "key": {"type": "string", "enum": AREAS},
                    "label": {"type": "string"},
                    "score": {"type": "number", "description": "0-10"},
                    "strengths": _STR_ARRAY,
                },
                "required": ["key", "label", "score", "strengths"],
                "additionalProperties": False,
            },
        },
        "issues": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "area": {"type": "string", "enum": AREAS},
                    "title": {"type": "string", "description": "Imperative, under 8 words"},
                    "observation": {"type": "string"},
                    "why_it_matters": {"type": "string"},
                    "steps": _STR_ARRAY,
                    "cost": {"type": "string", "enum": ["low", "medium", "high"]},
                    "effort": {"type": "string", "description": "e.g. '30 min', 'half a day'"},
                    "impact": {"type": "string", "enum": ["high", "medium", "low"]},
                    "target": {"type": ["string", "null"]},
                    "suggested_move": {
                        "type": ["object", "null"],
                        "properties": {
                            "object_id": {"type": "string"},
                            "dx_m": {"type": "number"},
                            "dz_m": {"type": "number"},
                            "rotate_deg": {"type": "number"},
                        },
                        "required": ["object_id", "dx_m", "dz_m", "rotate_deg"],
                        "additionalProperties": False,
                    },
                },
                "required": ["area", "title", "observation", "why_it_matters", "steps", "cost", "effort",
                             "impact", "target", "suggested_move"],
                "additionalProperties": False,
            },
        },
        "notes": _STR_ARRAY,
    },
    "required": ["overall", "verdict", "areas", "issues", "notes"],
    "additionalProperties": False,
}

_IMPACT = {"high": 3, "medium": 2, "low": 1}
_COST = {"low": 1, "medium": 2, "high": 3}


def missing_shots(shots: List[str], has_scan: bool) -> List[str]:
    required = REQUIRED_WITH_SCAN if has_scan else REQUIRED_WITHOUT_SCAN
    return [s for s in required if s not in shots]


def finalise(audit: ExperienceAudit) -> ExperienceAudit:
    """Number issues, drop targets/moves that don't match the scan, and order by impact per cost."""
    room_ids = set()
    if audit.room:
        room_ids = {o.id for o in audit.room.objects} | {e.id for e in audit.room.elements}
    for issue in audit.issues:
        t = issue.target
        if t and not (t in room_ids or (t.startswith("photo:") and t[6:] in audit.shots)):
            issue.target = None
        if issue.suggested_move and not (audit.room and layout.move_is_valid(audit.room, issue.suggested_move)):
            issue.suggested_move = None
        if issue.suggested_move and not issue.target:
            issue.target = issue.suggested_move.object_id
    audit.issues.sort(key=lambda i: -_IMPACT[i.impact] / _COST[i.cost])
    for n, issue in enumerate(audit.issues, 1):
        issue.id = f"issue-{n}"
    audit.overall = max(0.0, min(100.0, audit.overall))
    for area in audit.areas:
        area.score = max(0.0, min(10.0, area.score))
    return audit


async def analyse(shop: ShopProfile, room: Optional[RoomSummary], photos: Dict[str, Upload],
                  lang: str = i18n.EN) -> ExperienceAudit:
    metrics: Optional[LayoutMetrics] = layout.measure(room) if room and room.objects else None

    content: List[dict] = []
    for shot, (data, media_type) in photos.items():
        content.append({"type": "text", "text": f"Photo `{shot}`: {SHOTS.get(shot, shot)}"})
        content.append(llm.image_block(data, media_type))
    brief = {
        "shop": {"name": shop.name, "category": shop.category, "district": shop.district,
                 "avg_menu_price_hkd": shop.menu.avg_price if shop.menu else None},
        "photos_provided": list(photos),
        "scan": room.model_dump(mode="json") if room else None,
        "layout_metrics": metrics.model_dump(mode="json") if metrics else None,
    }
    content.append({"type": "text", "text": json.dumps(brief, ensure_ascii=False, sort_keys=True)})
    content.append({"type": "text", "text": "Review this shop's customer experience and write the fix plan."})

    data = await llm.structured(system=_SYSTEM + "\n" + i18n.write_in(lang), content=content,
                                schema=_SCHEMA, effort="high")
    audit = ExperienceAudit(
        shop_id=shop.id, lang=lang, overall=data["overall"], verdict=data["verdict"],
        areas=[ExperienceArea(**a) for a in data["areas"]],
        issues=[ExperienceIssue(id="", **{**i, "suggested_move": SuggestedMove(**i["suggested_move"]) if i["suggested_move"] else None})
                for i in data["issues"]],
        room=room, layout=metrics, shots=list(photos), notes=data["notes"],
    )
    return finalise(audit)
