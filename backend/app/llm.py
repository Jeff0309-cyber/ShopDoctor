"""Thin wrapper around the AI provider (Claude by default, or Gemini) shared by intake, enrichment and the Doctor."""

import json
from typing import Any, Dict, List, Optional

import anthropic

from . import config

# Server-side refusal fallback: if the primary model declines, the API re-runs
# the request on a fallback model inside the same call.
FALLBACK_KWARGS: Dict[str, Any] = {
    "betas": ["server-side-fallback-2026-07-01"],
    "fallbacks": "default",
}

_client: Optional[anthropic.AsyncAnthropic] = None


class LLMError(RuntimeError):
    pass


def client() -> anthropic.AsyncAnthropic:
    global _client
    if _client is None:
        _client = anthropic.AsyncAnthropic()
    return _client


def image_block(data_b64: str, media_type: str) -> Dict[str, Any]:
    if media_type == "application/pdf":
        return {"type": "document", "source": {"type": "base64", "media_type": media_type, "data": data_b64}}
    return {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": data_b64}}


async def structured(
    *,
    system: str,
    content: List[Dict[str, Any]],
    schema: Dict[str, Any],
    effort: str = "medium",
) -> Dict[str, Any]:
    """One request whose reply is JSON validated against `schema`."""
    if config.AI_PROVIDER == "gemini":
        from . import gemini
        try:
            return await gemini.structured(system=system, content=content, schema=schema)
        except gemini.GeminiError as e:
            raise LLMError(str(e)) from e

    response = await client().beta.messages.create(
        model=config.MODEL,
        max_tokens=16000,
        system=system,
        messages=[{"role": "user", "content": content}],
        output_config={"effort": effort, "format": {"type": "json_schema", "schema": schema}},
        **FALLBACK_KWARGS,
    )
    if response.stop_reason == "refusal":
        raise LLMError("The model declined this request.")
    if response.stop_reason == "max_tokens":
        raise LLMError("The model's reply was cut off.")
    text = next((b.text for b in response.content if b.type == "text"), None)
    if text is None:
        raise LLMError("The model returned no text.")
    return json.loads(text)
