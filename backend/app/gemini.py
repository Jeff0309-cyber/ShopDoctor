"""Google Gemini as ShopDoctor's AI provider (alternative to Claude; see config.AI_PROVIDER).

Mirrors what llm.py / enrich.py / doctor_agent.py ask of Claude: structured JSON, a grounded
search for closed shops, and a streaming tool-use loop for the Doctor chat. Content blocks are
the same Anthropic-shaped dicts the rest of the app builds, converted here.
"""

import asyncio
import base64
import json
import logging
from typing import Any, AsyncIterator, Callable, Dict, List, Optional

import httpx
from google import genai
from google.genai import errors, types

from . import config

log = logging.getLogger("shopdoctor")

_clients: Dict[int, genai.Client] = {}

# Status codes worth retrying on the next model in config.GEMINI_MODELS
# (503 = model overloaded, 429 = quota for that model used up).
_FALL_THROUGH = {429, 500, 503, 504}


class GeminiError(RuntimeError):
    pass


def client() -> genai.Client:
    """One client per event loop: its async connection pool can't be shared across loops."""
    loop = id(asyncio.get_running_loop())
    if loop not in _clients:
        _clients[loop] = genai.Client(api_key=config.GEMINI_API_KEY)
    return _clients[loop]


def to_parts(content: List[Dict[str, Any]]) -> List[types.Part]:
    """Anthropic-style blocks ({"type": "text"|"image"|"document", ...}) → Gemini parts."""
    parts: List[types.Part] = []
    for block in content:
        if block["type"] == "text":
            parts.append(types.Part.from_text(text=block["text"]))
        elif block["type"] in ("image", "document"):
            src = block["source"]
            parts.append(types.Part.from_bytes(data=base64.standard_b64decode(src["data"]), mime_type=src["media_type"]))
    return parts


async def _generate(contents: Any, cfg: types.GenerateContentConfig) -> types.GenerateContentResponse:
    last: Optional[Exception] = None
    for model in config.GEMINI_MODELS:
        try:
            return await client().aio.models.generate_content(model=model, contents=contents, config=cfg)
        except (errors.APIError, httpx.HTTPError) as e:
            last = e
            if isinstance(e, errors.APIError) and e.code not in _FALL_THROUGH:
                break
            log.info("Gemini %s unavailable (%s); trying the next model", model, getattr(e, "code", type(e).__name__))
    raise GeminiError(f"Gemini request failed: {last}")


async def structured(*, system: str, content: List[Dict[str, Any]], schema: Dict[str, Any]) -> Dict[str, Any]:
    cfg = types.GenerateContentConfig(
        system_instruction=system,
        response_mime_type="application/json",
        response_json_schema=schema,
    )
    response = await _generate(to_parts(content), cfg)
    if not response.text:
        reason = response.candidates[0].finish_reason if response.candidates else "no candidates"
        raise GeminiError(f"Gemini returned no text ({reason}).")
    return json.loads(response.text)


async def grounded_then_structured(*, prompt: str, schema: Dict[str, Any], extract_instruction: str) -> Dict[str, Any]:
    """Search the web with Google Search grounding, then turn the findings into JSON.

    Two calls, because grounding and a response schema can't always be combined.
    """
    search_cfg = types.GenerateContentConfig(tools=[types.Tool(google_search=types.GoogleSearch())])
    found = await _generate(prompt, search_cfg)
    sources: List[str] = []
    meta = found.candidates[0].grounding_metadata if found.candidates else None
    for chunk in (meta.grounding_chunks or []) if meta else []:
        if chunk.web and chunk.web.uri:
            sources.append(f"- {chunk.web.title or ''}: {chunk.web.uri}")
    notes = (found.text or "") + ("\n\nSources:\n" + "\n".join(sources) if sources else "")
    return await structured(system=extract_instruction, content=[{"type": "text", "text": notes}], schema=schema)


# ---------- Doctor chat ----------

def _function_tools(tools: List[Dict[str, Any]]) -> List[types.Tool]:
    return [types.Tool(function_declarations=[
        types.FunctionDeclaration(name=t["name"], description=t["description"], parameters_json_schema=t["input_schema"])
        for t in tools
    ])]


async def chat_stream(
    *,
    system: str,
    history: List[Dict[str, str]],
    tools: List[Dict[str, Any]],
    run_tool: Callable[[str, Dict[str, Any]], Optional[str]],
) -> AsyncIterator[Dict[str, Any]]:
    """Yields {"type": "text"|"tool", ...} events; `run_tool` returns None for invalid input."""
    contents: List[types.Content] = [
        types.Content(role="model" if m["role"] == "assistant" else "user", parts=[types.Part.from_text(text=m["content"])])
        for m in history
    ]
    cfg = types.GenerateContentConfig(
        system_instruction=system,
        tools=_function_tools(tools),
        automatic_function_calling=types.AutomaticFunctionCallingConfig(disable=True),
    )

    for _ in range(8):
        parts: List[types.Part] = []
        calls: List[types.FunctionCall] = []
        for model in config.GEMINI_MODELS:
            streamed = False
            try:
                stream = await client().aio.models.generate_content_stream(model=model, contents=contents, config=cfg)
                async for chunk in stream:
                    if not chunk.candidates or not chunk.candidates[0].content:
                        continue
                    for part in chunk.candidates[0].content.parts or []:
                        parts.append(part)  # keep every part, including thought signatures, for the next turn
                        if part.function_call:
                            calls.append(part.function_call)
                        elif part.text and not part.thought:
                            streamed = True
                            yield {"type": "text", "text": part.text}
                break
            except (errors.APIError, httpx.HTTPError) as e:
                # Overloaded or out of quota: try the next model, but only if the owner hasn't seen any text yet.
                retryable = not isinstance(e, errors.APIError) or e.code in _FALL_THROUGH
                if streamed or not retryable or model == config.GEMINI_MODELS[-1]:
                    raise GeminiError(f"Gemini stream failed: {e}") from e
                log.info("Gemini %s unavailable during chat; trying the next model", model)
                parts, calls = [], []

        if not calls:
            return
        contents.append(types.Content(role="model", parts=parts))
        responses = []
        for call in calls:
            yield {"type": "tool", "name": call.name}
            result = run_tool(call.name, dict(call.args or {}))
            payload = {"error": "invalid arguments"} if result is None else {"result": result}
            responses.append(types.Part.from_function_response(name=call.name, response=payload))
        contents.append(types.Content(role="user", parts=responses))
