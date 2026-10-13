"""Compare the owner's shop with its twins and compute the Health Score.

Every function here is pure so the scoring model can be unit-tested and
tuned without touching any external API.
"""

import math
import statistics
from typing import Callable, Dict, List, Optional, Tuple

from . import config, i18n
from .schemas import (
    Comparison, CostSlice, Financials, Finding, HealthScore, ShopProfile, SubScore, TwinShop,
)
from .twins import price_level_from_avg

Features = Dict[str, Optional[float]]


# ---------- features ----------

# name -> (label, unit, normaliser to 0..1, how to phrase a value)
FEATURES: Dict[str, Tuple[str, str, Callable[[float], float], Callable[[float], str]]] = {
    "rating": ("Google rating", "★", lambda v: v / 5, lambda v: f"{v:.1f}★"),
    "review_count": ("Number of reviews", "reviews",
                     lambda v: min(math.log1p(v) / math.log1p(3000), 1.0), lambda v: f"{v:,.0f} reviews"),
    "price_level": ("Price level", "/4", lambda v: v / 4, lambda v: "$" * max(int(round(v)), 1)),
    "weekly_hours": ("Opening hours", "h/week", lambda v: min(v / 112, 1.0), lambda v: f"{v:.0f} h/week"),
    "mtr_distance_m": ("Distance to MTR", "m", lambda v: 1 - min(v, 1500) / 1500, lambda v: f"{v:,.0f} m"),
    "photo_count": ("Online photos", "photos", lambda v: min(v, 10) / 10, lambda v: f"{v:.0f} photos"),
}

# Features where a *lower* raw value is the healthier one.
LOWER_IS_BETTER = {"mtr_distance_m"}


def feature_label(key: str, lang: str) -> str:
    return i18n.t(lang, "feat." + key)


def fmt_value(key: str, v: float, lang: str) -> str:
    """Phrase a feature value for the owner, e.g. "88 h/week" or "每週88小時"."""
    if key == "rating":
        return f"{v:.1f}★"
    if key == "price_level":
        return "$" * max(int(round(v)), 1)
    fmt_key = {"review_count": "fmt.reviews", "weekly_hours": "fmt.hours",
               "mtr_distance_m": "fmt.meters", "photo_count": "fmt.photos"}[key]
    return i18n.t(lang, fmt_key, n=f"{v:,.0f}")


def twin_features(t: TwinShop) -> Features:
    return {
        "rating": t.rating,
        "review_count": float(t.review_count) if t.review_count is not None else None,
        "price_level": float(t.price_level) if t.price_level is not None else None,
        "weekly_hours": t.weekly_hours,
        "mtr_distance_m": t.mtr_distance_m,
        "photo_count": float(t.photo_count) if t.photo_count is not None else None,
    }


def owner_features(shop: ShopProfile, listing: Optional[TwinShop], mtr_distance_m: Optional[float]) -> Features:
    """The owner's own Google listing (if found) plus what they told us."""
    f = twin_features(listing) if listing else {k: None for k in FEATURES}
    menu_level = price_level_from_avg(shop.menu.avg_price if shop.menu else None)
    if menu_level is not None:
        f["price_level"] = float(menu_level)
    if shop.weekly_hours is not None:
        f["weekly_hours"] = shop.weekly_hours
    if mtr_distance_m is not None:
        f["mtr_distance_m"] = mtr_distance_m
    return f


def similarity(a: Features, b: Features, distance_m: Optional[float] = None) -> float:
    """1 − mean absolute difference over normalised shared features, nudged by proximity."""
    diffs = [
        abs(FEATURES[k][2](a[k]) - FEATURES[k][2](b[k]))
        for k in FEATURES
        if a.get(k) is not None and b.get(k) is not None
    ]
    base = 1 - statistics.mean(diffs) if diffs else 0.5
    confidence = len(diffs) / (len(diffs) + 1)  # few shared features → pull toward 0.5
    score = 0.5 + (base - 0.5) * confidence
    if distance_m is not None:
        score *= 0.85 + 0.15 * (1 - min(distance_m, 1500) / 1500)
    return round(max(0.0, min(1.0, score)), 3)


# ---------- comparison ----------

def _mean(values: List[Optional[float]]) -> Optional[float]:
    present = [v for v in values if v is not None]
    return statistics.mean(present) if present else None


def compare(owner: Features, twins: List[TwinShop], k: int = config.NEAREST_K, lang: str = i18n.EN) -> Comparison:
    for t in twins:
        t.similarity = similarity(owner, twin_features(t), t.distance_m)

    survivors = sorted((t for t in twins if t.status == "survivor"), key=lambda t: -t.similarity)
    closed = sorted((t for t in twins if t.status == "closed"), key=lambda t: -t.similarity)
    near_s, near_c = survivors[:k], closed[:k]

    findings: List[Finding] = []
    for key, (_, unit, norm, _) in FEATURES.items():
        label = feature_label(key, lang)
        # Compare across the whole group for stable averages; nearest twins drive similarity.
        s_avg = _mean([twin_features(t)[key] for t in survivors])
        c_avg = _mean([twin_features(t)[key] for t in closed])
        mine = owner.get(key)
        if s_avg is None or c_avg is None:
            continue
        gap = abs(norm(s_avg) - norm(c_avg))
        verdict = "neutral"
        if mine is not None and gap >= 0.04:
            verdict = "like_survivors" if abs(mine - s_avg) <= abs(mine - c_avg) else "like_closed"
        findings.append(Finding(
            feature=key, label=label, unit=unit, owner=mine,
            survivors_avg=round(s_avg, 2), closed_avg=round(c_avg, 2),
            verdict=verdict, gap=round(gap, 3),
            message=_finding_message(key, label, mine, s_avg, c_avg, verdict, lang),
        ))
    findings.sort(key=lambda f: (f.verdict != "like_closed", -f.gap))

    n_s, n_c = len(survivors), len(closed)
    return Comparison(
        survivor_count=n_s,
        closed_count=n_c,
        closure_rate=round(n_c / (n_s + n_c), 3) if n_s + n_c else 0.0,
        survivor_similarity=round(_mean([t.similarity for t in near_s]) or 0.0, 3),
        closed_similarity=round(_mean([t.similarity for t in near_c]) or 0.0, 3),
        nearest_survivor_ids=[t.id for t in near_s],
        nearest_closed_ids=[t.id for t in near_c],
        findings=findings,
    )


def _finding_message(key: str, label: str, mine: Optional[float],
                     s_avg: float, c_avg: float, verdict: str, lang: str) -> str:
    def fmt(v: float) -> str:
        return fmt_value(key, v, lang)

    base = i18n.t(lang, "finding.base", label=label, s=fmt(s_avg), c=fmt(c_avg))
    if mine is None:
        return base + i18n.t(lang, "finding.unknown")
    tail = {"like_closed": "finding.like_closed", "like_survivors": "finding.like_survivors"}.get(verdict, "finding.neutral")
    return base + i18n.t(lang, tail, m=fmt(mine))


# ---------- financials ----------

def financials(shop: ShopProfile, lang: str = i18n.EN) -> Financials:
    recent = [m.amount for m in sorted(shop.monthly_revenue, key=lambda m: m.month)[-3:]]
    revenue = statistics.mean(recent) if recent else 0.0
    c = shop.costs
    total = c.total
    ratio = (lambda x: round(x / revenue, 3)) if revenue else (lambda x: 0.0)
    return Financials(
        revenue=round(revenue, 2),
        total_costs=round(total, 2),
        net_profit=round(revenue - total, 2),
        net_margin=ratio(revenue - total),
        rent_ratio=ratio(c.rent),
        staff_ratio=ratio(c.staff),
        ingredient_ratio=ratio(c.ingredients),
        cost_breakdown=[
            CostSlice(category=i18n.t(lang, "cost." + name), amount=amount)
            for name, amount in (
                ("rent", c.rent), ("staff", c.staff), ("ingredients", c.ingredients),
                ("utilities", c.utilities), ("other", c.other),
            )
            if amount > 0
        ],
    )


# ---------- health score ----------

def lin(value: float, good: float, bad: float) -> float:
    """100 at `good`, 0 at `bad`, linear and clamped in between (either direction)."""
    if good == bad:
        return 100.0
    t = (value - bad) / (good - bad)
    return round(max(0.0, min(1.0, t)) * 100, 1)


def health_score(shop: ShopProfile, owner: Features, fin: Financials,
                 comp: Comparison, twins: List[TwinShop], lang: str = i18n.EN,
                 experience_score: Optional[float] = None) -> HealthScore:
    b = config.BENCHMARKS
    subs: Dict[str, Tuple[str, float, str]] = {}

    def T(key: str, **kw) -> str:
        return i18n.t(lang, key, **kw)

    label = {k: T("sub." + k) for k in config.HEALTH_WEIGHTS}

    # Location
    mtr = owner.get("mtr_distance_m")
    if mtr is not None:
        subs["location"] = (label["location"], lin(mtr, b["mtr_good_m"], b["mtr_bad_m"]), T("loc.mtr", d=f"{mtr:,.0f}"))
    else:
        subs["location"] = (label["location"], 60.0, T("loc.unknown"))

    # Pricing vs survivors
    my_level = owner.get("price_level")
    surv_levels = [t.price_level for t in twins if t.status == "survivor" and t.price_level is not None]
    if my_level is not None and surv_levels:
        target = statistics.median(surv_levels)
        score = max(0.0, 100 - 35 * abs(my_level - target))
        subs["pricing"] = (label["pricing"], score, T("price.compare", mine="$" * max(int(my_level), 1),
                                                       target="$" * max(int(round(target)), 1)))
    else:
        subs["pricing"] = (label["pricing"], 60.0, T("price.unknown"))

    # Menu
    if shop.menu and shop.menu.item_count:
        score = shop.menu.clarity_score * 10
        note = T("menu.summary", c=f"{shop.menu.clarity_score:.0f}", n=shop.menu.item_count)
        if shop.menu.item_count > 120:
            score -= 15
            note += T("menu.long")
        elif shop.menu.item_count < 8:
            score -= 10
            note += T("menu.short")
        subs["menu"] = (label["menu"], max(0.0, score), note)
    else:
        subs["menu"] = (label["menu"], 60.0, T("menu.none"))

    # Visibility (shopfront + online presence)
    parts, notes = [], []
    if shop.shopfront:
        sf = shop.shopfront
        parts.append((statistics.mean([sf.signage_score, sf.visibility_score, sf.condition_score, sf.appeal_score]) * 10, 0.7))
        notes.append(T("vis.front", s=f"{sf.signage_score:.0f}", v=f"{sf.visibility_score:.0f}"))
    if experience_score is not None:  # the in-shop experience check, when the owner has done one
        parts.append((experience_score, 0.5))
        notes.append(T("vis.experience", n=f"{experience_score:.0f}"))
    if owner.get("review_count") is not None:
        online = FEATURES["review_count"][2](owner["review_count"]) * 100
        parts.append((online, 0.3))
        notes.append(T("vis.reviews", n=f"{owner['review_count']:,.0f}"))
    if parts:
        score = sum(s * w for s, w in parts) / sum(w for _, w in parts)
        subs["visibility"] = (label["visibility"], round(score, 1), ("" if lang == i18n.ZH else " ").join(notes))
    else:
        subs["visibility"] = (label["visibility"], 60.0, T("vis.none"))

    # Financials
    if fin.revenue > 0:
        checks = [("net margin", lin(fin.net_margin, b["net_margin_good"], b["net_margin_bad"]))]
        if shop.costs.rent:
            checks.append(("rent", lin(fin.rent_ratio, b["rent_ratio_good"], b["rent_ratio_bad"])))
        if shop.costs.staff:
            checks.append(("staff", lin(fin.staff_ratio, b["staff_ratio_good"], b["staff_ratio_bad"])))
        if shop.costs.ingredients:
            checks.append(("ingredients", lin(fin.ingredient_ratio, b["ingredient_ratio_good"], b["ingredient_ratio_bad"])))
        weakest = min(checks, key=lambda c: c[1])
        subs["financials"] = (
            label["financials"], round(statistics.mean(s for _, s in checks), 1),
            T("fin.summary", m=f"{fin.net_margin:.0%}", r=f"{fin.rent_ratio:.0%}", w=T("fin." + weakest[0])),
        )
    else:
        subs["financials"] = (label["financials"], 50.0, T("fin.none"))

    # Market
    if comp.survivor_count + comp.closed_count:
        survival = 1 - comp.closure_rate
        resemblance = max(0.0, min(1.0, 0.5 + 2 * (comp.survivor_similarity - comp.closed_similarity)))
        leaning = T("mkt.survivors") if resemblance >= 0.5 else T("mkt.closed")
        subs["market"] = (
            label["market"], round(60 * survival + 40 * resemblance, 1),
            T("mkt.summary", rate=f"{comp.closure_rate:.0%}", leaning=leaning),
        )
    else:
        subs["market"] = (label["market"], 60.0, T("mkt.none"))

    subscores = [
        SubScore(key=k, label=subs[k][0], score=subs[k][1], weight=w, explanation=subs[k][2])
        for k, w in config.HEALTH_WEIGHTS.items()
    ]
    overall = round(sum(s.score * s.weight for s in subscores), 1)
    band = "healthy" if overall >= 75 else "watch" if overall >= 55 else "at_risk"
    return HealthScore(overall=overall, band=band, subscores=subscores)
