"""Turn a diagnosis into the top 3 prescriptions shown on the dashboard."""

import json
from typing import List, Optional

from . import i18n, llm
from .schemas import Diagnosis, ExperienceAudit, Prescription, ShopProfile

_SCHEMA = {
    "type": "object",
    "properties": {
        "prescriptions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Imperative, under 8 words"},
                    "detail": {"type": "string", "description": "2-3 sentences: what to do and how"},
                    "impact": {"type": "string", "enum": ["high", "medium", "low"]},
                    "evidence": {"type": "string", "description": "The metric or twin shops this rests on"},
                },
                "required": ["title", "detail", "impact", "evidence"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["prescriptions"],
    "additionalProperties": False,
}

_SYSTEM = (
    "You are ShopDoctor, a practical business consultant for small shops in Hong Kong. "
    "Given a shop's diagnosis, write the three changes most likely to keep it open, ordered by impact. "
    "Each must rest on a specific number or twin shop from the data; never invent figures. "
    "Prefer cheap, fast actions an owner-operator can take this month."
)


def diagnosis_brief(shop: ShopProfile, d: Diagnosis, experience: Optional[ExperienceAudit] = None) -> str:
    twins = {t.id: t for t in d.twins}
    nearest = [twins[i] for i in d.comparison.nearest_survivor_ids + d.comparison.nearest_closed_ids if i in twins]
    payload = {
        "shop": shop.model_dump(mode="json", exclude={"menu": {"items"}}),
        "health": d.health.model_dump(mode="json"),
        "financials": d.financials.model_dump(mode="json"),
        "comparison": d.comparison.model_dump(mode="json"),
        "nearest_twins": [t.model_dump(mode="json", exclude_none=True) for t in nearest],
        "forecast": {k: v for k, v in d.forecast.model_dump(mode="json").items() if k != "points"},
    }
    if experience:
        payload["shop_experience"] = experience_brief(experience)
    return json.dumps(payload, ensure_ascii=False, sort_keys=True)


async def prescribe(shop: ShopProfile, d: Diagnosis, lang: str = i18n.EN,
                    experience: Optional[ExperienceAudit] = None) -> List[Prescription]:
    data = await llm.structured(
        system=_SYSTEM + " " + i18n.write_in(lang),
        content=[{"type": "text", "text": diagnosis_brief(shop, d, experience)}],
        schema=_SCHEMA,
        effort="high",
    )
    return [Prescription(**p) for p in data["prescriptions"][:3]]


def experience_brief(a: ExperienceAudit) -> dict:
    """The parts of a shop-experience audit worth reasoning over (no raw geometry)."""
    return {
        "overall": a.overall,
        "verdict": a.verdict,
        "layout": a.layout.model_dump(mode="json") if a.layout else None,
        "issues": [i.model_dump(mode="json", exclude={"suggested_move"}) for i in a.issues],
    }


def heuristic_prescriptions(d: Diagnosis, lang: str = i18n.EN) -> List[Prescription]:
    """Rule-based fallback used in demo mode or when the model is unavailable."""
    def low(label: str) -> str:
        return label if lang == i18n.ZH else label.lower()

    out: List[Prescription] = []
    for f in d.comparison.findings:
        if f.verdict == "like_closed":
            out.append(Prescription(
                title=i18n.t(lang, "rx.gap.title", label=low(f.label)),
                detail=i18n.t(lang, "rx.gap.detail", message=f.message),
                impact="high" if f.gap > 0.15 else "medium",
                evidence=i18n.t(lang, "rx.gap.evidence", s=f.survivors_avg, c=f.closed_avg),
            ))
    for s in sorted(d.health.subscores, key=lambda s: s.score):
        if s.score < 60:
            out.append(Prescription(title=i18n.t(lang, "rx.sub.title", label=low(s.label)), detail=s.explanation,
                                    impact="medium", evidence=i18n.t(lang, "rx.sub.evidence", label=s.label, n=f"{s.score:.0f}")))
    return out[:3]
