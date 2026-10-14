"""The Doctor: a chat agent that reads the diagnosis through tools and explains it."""

import asyncio
import json
from typing import Any, AsyncIterator, Dict, List, Optional

from . import config, i18n, llm, scoring, store
from .prescribe import diagnosis_brief, experience_brief
from .schemas import ChatMessage, Diagnosis, ShopProfile

SYSTEM = """You are ShopDoctor, a warm, plain-spoken business doctor for small shops in Hong Kong.

The owner is talking to you inside the ShopDoctor app after a diagnosis of their shop. The diagnosis compares their shop with nearby "twin" shops of the same type, split into survivors (still open) and closed shops.

How to work:
- Use the tools to look at the diagnosis, the twin shops and what-if scenarios before you answer. Never invent numbers; if the data doesn't cover something, say so.
- Ground every suggestion in evidence: a metric, a finding, or a named twin shop ("Lotus Café, 300 m away and still open, opens 7 days a week").
- When the owner considers a change (raise prices, cut hours, move, renegotiate rent), run what_if and report the result.
- Be honest about uncertainty: twin data is incomplete and the forecast is a range, not a promise.
- Reply in the app language given below. If the owner writes in the other language, follow them. Chinese replies use standard written Traditional Chinese (書面語) as used in Hong Kong.
- Keep replies short enough to read on a phone: a direct answer first, then at most 3-5 bullets. Use HKD."""

TOOLS: List[Dict[str, Any]] = [
    {
        "name": "get_diagnosis",
        "description": "The shop profile, Health Score with sub-scores, financials, survivor-vs-closed findings, forecast summary and the nearest twin shops.",
        "input_schema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "list_twins",
        "description": "List twin shops, most similar first. Filter by status.",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "enum": ["survivor", "closed", "all"]},
                "limit": {"type": "integer", "minimum": 1, "maximum": 30},
            },
            "required": ["status"],
            "additionalProperties": False,
        },
    },
    {
        "name": "get_shop_experience",
        "description": "The in-shop experience check, if the owner has done one: score, layout measurements from the 3D scan, and the fix plan with each issue's steps.",
        "input_schema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "what_if",
        "description": (
            "Simulate the monthly effect of changes on revenue, costs and margin. All fields optional; "
            "percentages are fractions (0.1 = +10%). Uses a price elasticity assumption, so treat results as estimates."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "price_change_pct": {"type": "number"},
                "hours_change_pct": {"type": "number"},
                "rent_change_hkd": {"type": "number", "description": "Change in monthly rent, e.g. -5000"},
                "staff_change_hkd": {"type": "number", "description": "Change in monthly staff cost"},
                "ingredient_cost_change_pct": {"type": "number", "description": "Change in unit ingredient cost"},
            },
            "additionalProperties": False,
        },
    },
]
for _tool in TOOLS:
    _tool["eager_input_streaming"] = True


def what_if(shop: ShopProfile, args: Dict[str, Any]) -> Dict[str, Any]:
    fin = scoring.financials(shop)
    c = shop.costs
    p = float(args.get("price_change_pct") or 0)
    h = float(args.get("hours_change_pct") or 0)
    volume = (1 + config.PRICE_ELASTICITY * p) * (1 + 0.6 * h)  # longer hours bring diminishing extra trade
    revenue = fin.revenue * (1 + p) * volume
    ingredients = c.ingredients * volume * (1 + float(args.get("ingredient_cost_change_pct") or 0))
    staff = c.staff * (1 + 0.8 * h) + float(args.get("staff_change_hkd") or 0)
    utilities = c.utilities * (1 + 0.5 * h)
    rent = c.rent + float(args.get("rent_change_hkd") or 0)
    total = rent + staff + ingredients + utilities + c.other
    after = {
        "revenue": round(revenue), "total_costs": round(total), "net_profit": round(revenue - total),
        "net_margin": round((revenue - total) / revenue, 3) if revenue else None,
        "rent_ratio": round(rent / revenue, 3) if revenue else None,
    }
    before = {k: getattr(fin, k) for k in after}
    fixed = rent + staff + utilities + c.other
    var_ratio = ingredients / revenue if revenue else 0
    return {
        "before": before,
        "after": after,
        "monthly_profit_change": round((revenue - total) - fin.net_profit),
        "break_even_revenue_after": round(fixed / (1 - var_ratio)) if var_ratio < 0.95 else None,
        "assumptions": f"Price elasticity {config.PRICE_ELASTICITY}; extra hours add 60% proportional trade.",
    }


def _valid(name: str, args: Any) -> bool:
    if not isinstance(args, dict):
        return False
    if name == "list_twins":
        return args.get("status") in ("survivor", "closed", "all")
    if name == "what_if":
        return all(isinstance(v, (int, float)) for v in args.values())
    return True


def run_tool(name: str, args: Dict[str, Any], shop: ShopProfile, d: Diagnosis) -> str:
    if name == "get_diagnosis":
        return diagnosis_brief(shop, d)
    if name == "list_twins":
        status, limit = args["status"], int(args.get("limit") or 10)
        rows = [t for t in d.twins if status == "all" or t.status == status]
        rows.sort(key=lambda t: -t.similarity)
        return json.dumps([t.model_dump(mode="json", exclude_none=True) for t in rows[:limit]], ensure_ascii=False)
    if name == "what_if":
        return json.dumps(what_if(shop, args))
    if name == "get_shop_experience":
        audit = store.load_experience(shop.id)
        return json.dumps(experience_brief(audit) if audit else {"status": "not done yet"}, ensure_ascii=False)
    return json.dumps({"error": f"unknown tool {name}"})


def _sse(event: Dict[str, Any]) -> str:
    return f"data: {json.dumps(event, ensure_ascii=False)}\n\n"


async def chat(shop: ShopProfile, d: Diagnosis, history: List[ChatMessage], lang: str = i18n.EN) -> AsyncIterator[str]:
    if config.DEMO_MODE:
        async for chunk in _demo_reply(d, lang):
            yield chunk
        return

    system = SYSTEM + "\n\nApp language: " + ("Traditional Chinese (zh-HK)." if lang == i18n.ZH else "English.")
    if config.AI_PROVIDER == "gemini":
        async for chunk in _chat_gemini(shop, d, history, system):
            yield chunk
        return

    messages: List[Dict[str, Any]] = [{"role": m.role, "content": m.content} for m in history]
    try:
        for _ in range(8):
            async with llm.client().beta.messages.stream(
                model=config.MODEL,
                max_tokens=64000,
                system=system,
                tools=TOOLS,
                messages=messages,
                output_config={"effort": "medium"},
                **llm.FALLBACK_KWARGS,
            ) as stream:
                async for event in stream:
                    if event.type == "text":
                        yield _sse({"type": "text", "text": event.text})
                response = await stream.get_final_message()

            if response.stop_reason == "refusal":
                yield _sse({"type": "text", "text": "\n\nI can't help with that one — try asking about your shop's numbers."})
                break
            tool_uses = [b for b in response.content if b.type == "tool_use"]
            if not tool_uses:
                break
            if response.stop_reason == "max_tokens":
                break  # a truncated tool input isn't safe to run

            messages.append({"role": "assistant", "content": response.content})
            results = []
            for block in tool_uses:
                yield _sse({"type": "tool", "name": block.name})
                if not _valid(block.name, block.input):
                    results.append({"type": "tool_result", "tool_use_id": block.id, "is_error": True,
                                    "content": json.dumps({"INVALID_JSON": json.dumps(block.input)})})
                    continue
                results.append({"type": "tool_result", "tool_use_id": block.id,
                                "content": run_tool(block.name, block.input, shop, d)})
            messages.append({"role": "user", "content": results})
    except ValueError:
        yield _sse({"type": "error", "message": "The Doctor's reply was garbled. Please ask again."})
    except Exception as e:  # surface API/network failures to the app instead of a dropped stream
        yield _sse({"type": "error", "message": f"The Doctor is unavailable: {type(e).__name__}"})
    yield _sse({"type": "done"})


async def _chat_gemini(shop: ShopProfile, d: Diagnosis, history: List[ChatMessage], system: str) -> AsyncIterator[str]:
    from . import gemini

    def tool(name: str, args: Dict[str, Any]) -> Optional[str]:
        return run_tool(name, args, shop, d) if _valid(name, args) else None

    try:
        async for event in gemini.chat_stream(
            system=system, history=[{"role": m.role, "content": m.content} for m in history],
            tools=[{k: t[k] for k in ("name", "description", "input_schema")} for t in TOOLS], run_tool=tool,
        ):
            yield _sse(event)
    except gemini.GeminiError:
        yield _sse({"type": "error", "message": "The Doctor is unavailable right now. Please try again in a minute."})
    yield _sse({"type": "done"})


async def _demo_reply(d: Diagnosis, lang: str) -> AsyncIterator[str]:
    weakest = min(d.health.subscores, key=lambda s: s.score)
    text = (
        i18n.t(lang, "demo.doctor_intro") + "\n\n"
        + i18n.t(lang, "demo.doctor_score", n=f"{d.health.overall:.0f}")
        + i18n.t(lang, "demo.doctor_weakest", label=weakest.label if lang == i18n.ZH else weakest.label.lower(),
                 n=f"{weakest.score:.0f}", why=weakest.explanation) + "\n\n"
        + "".join(f"• {p.title} — {p.evidence}\n" for p in d.prescriptions)
    )
    for i in range(0, len(text), 6):  # stream in small chunks, like the real model
        yield _sse({"type": "text", "text": text[i:i + 6]})
        await asyncio.sleep(0.02)
    yield _sse({"type": "done"})
