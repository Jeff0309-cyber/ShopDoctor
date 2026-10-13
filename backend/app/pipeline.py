"""Run a full diagnosis: twins → comparison → health → forecast → prescriptions."""

import logging
from datetime import date
from typing import List, Optional

import anthropic
import httpx

from . import config, demo, enrich, forecast, i18n, prescribe, scoring, store, twins
from .schemas import Diagnosis, ShopProfile, TwinShop

log = logging.getLogger("shopdoctor")


def break_even_revenue(shop: ShopProfile, revenue: float) -> float:
    """Revenue at which fixed costs are covered, treating ingredients as variable."""
    c = shop.costs
    fixed = c.rent + c.staff + c.utilities + c.other
    variable_ratio = c.ingredients / revenue if revenue else 0.0
    return fixed / (1 - variable_ratio) if variable_ratio < 0.95 else fixed


async def diagnose(shop: ShopProfile, lang: str = i18n.EN) -> Diagnosis:
    notes: List[str] = []
    own_listing: Optional[TwinShop] = None
    own_mtr: Optional[float] = None

    if config.DEMO_MODE:
        twin_list = demo.sample_twins(shop, lang=lang)
        own_mtr = 520.0
        notes.append(i18n.t(lang, "note.demo"))
    else:
        try:
            search = await twins.find_twins(shop)
            twin_list, own_listing, own_mtr = search.twins, search.own_listing, search.own_mtr_m
        except httpx.HTTPError as e:
            log.warning("Places search failed: %s", e)
            twin_list = []
            notes.append(i18n.t(lang, "note.places_failed"))
        try:
            twin_list += await enrich.find_closed_shops(shop, twin_list, lang=lang)
        except anthropic.APIError as e:
            log.warning("Closed-shop web search failed: %s", e)
            notes.append(i18n.t(lang, "note.web_failed"))
        if own_listing is None:
            notes.append(i18n.t(lang, "note.not_listed"))

    owner = scoring.owner_features(shop, own_listing, own_mtr)
    comparison = scoring.compare(owner, twin_list, lang=lang)
    fin = scoring.financials(shop, lang=lang)
    experience = store.load_experience(shop.id)
    health = scoring.health_score(shop, owner, fin, comparison, twin_list, lang=lang,
                                  experience_score=experience.overall if experience else None)
    fc = forecast.project(
        shop.monthly_revenue, health.overall, break_even_revenue(shop, fin.revenue),
        start_month=date.today().strftime("%Y-%m"), lang=lang,
    )
    if comparison.closed_count < 3:
        notes.append(i18n.t(lang, "note.few_closed", n=comparison.closed_count))

    d = Diagnosis(shop_id=shop.id, health=health, financials=fin, twins=twin_list,
                  comparison=comparison, forecast=fc, data_notes=notes)

    if config.DEMO_MODE:
        d.prescriptions = prescribe.heuristic_prescriptions(d, lang)
    else:
        try:
            d.prescriptions = await prescribe.prescribe(shop, d, lang, experience)
        except (anthropic.APIError, prescribe.llm.LLMError) as e:
            log.warning("Prescriptions failed: %s", e)
            d.prescriptions = prescribe.heuristic_prescriptions(d, lang)
    return d
