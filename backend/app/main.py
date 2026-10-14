"""ShopDoctor HTTP API."""

import base64
import logging
import uuid
from typing import List, Optional

import anthropic
from pathlib import Path

from fastapi import FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import ValidationError
from starlette.datastructures import UploadFile as StarletteUpload  # what request.form() yields

from . import config, demo, doctor_agent, experience, i18n, intake, pipeline, ratelimit, store
from .schemas import ChatRequest, Diagnosis, ExperienceAudit, RoomSummary, ShopInput, ShopProfile

logging.basicConfig(level=logging.INFO)
app = FastAPI(title="ShopDoctor API", version="0.1.0")
WEB_DIR = Path(__file__).resolve().parent.parent / "web"


@app.middleware("http")
async def limit_ai_usage(request: Request, call_next):
    blocked = ratelimit.check(request)
    return blocked if blocked is not None else await call_next(request)

_ALLOWED = {"image/jpeg", "image/png", "image/webp", "image/gif", "application/pdf"}
_MAX_BYTES = 8 * 1024 * 1024


async def _read(files: List[StarletteUpload]) -> List[intake.Upload]:
    out = []
    for f in files:
        if f.content_type not in _ALLOWED:
            raise HTTPException(415, f"{f.filename}: unsupported type {f.content_type}")
        data = await f.read()
        if len(data) > _MAX_BYTES:
            raise HTTPException(413, f"{f.filename} is larger than 8 MB")
        out.append((base64.standard_b64encode(data).decode(), f.content_type))
    return out


def _shop_or_404(shop_id: str) -> ShopProfile:
    try:
        shop = store.load_shop(shop_id)
    except ValueError:
        shop = None
    if shop is None:
        raise HTTPException(404, "Shop not found")
    return shop


@app.get("/health")
async def health() -> dict:
    return {"ok": True, "demo_mode": config.DEMO_MODE}


@app.post("/v1/shops", response_model=ShopProfile)
async def create_shop(
    shop: str = Form(..., description="ShopInput as JSON"),
    menu_photos: List[UploadFile] = File(default=[]),
    shopfront_photos: List[UploadFile] = File(default=[]),
    financial_docs: List[UploadFile] = File(default=[]),
    accept_language: Optional[str] = Header(None),
) -> ShopProfile:
    lang = i18n.norm(accept_language)
    try:
        data = ShopInput.model_validate_json(shop)
    except ValidationError as e:
        raise HTTPException(422, e.errors()) from e
    profile = ShopProfile(id=uuid.uuid4().hex, lang=lang, **data.model_dump())
    menu, front, docs = await _read(menu_photos), await _read(shopfront_photos), await _read(financial_docs)

    if config.DEMO_MODE:
        profile.menu = demo.sample_menu(lang) if menu else None
        profile.shopfront = demo.sample_shopfront(lang) if front else None
    else:
        try:
            profile.menu = await intake.analyse_menu(menu, lang)
            profile.shopfront = await intake.analyse_shopfront(front, lang)
            revenue, costs = await intake.read_financials(docs, lang)
        except (anthropic.APIError, intake.llm.LLMError) as e:
            raise HTTPException(502, f"Couldn't read the photos: {e}") from e
        # Numbers the owner typed win over numbers read from a photo.
        if revenue and not profile.monthly_revenue:
            profile.monthly_revenue = revenue
        if costs and profile.costs.total == 0:
            profile.costs = costs

    store.save_shop(profile)
    return profile


@app.put("/v1/shops/{shop_id}", response_model=ShopProfile)
async def update_shop(shop_id: str, data: ShopInput) -> ShopProfile:
    shop = _shop_or_404(shop_id)
    updated = shop.model_copy(update=data.model_dump())
    store.save_shop(updated)
    return updated


@app.get("/v1/shops/{shop_id}", response_model=ShopProfile)
async def get_shop(shop_id: str) -> ShopProfile:
    return _shop_or_404(shop_id)


@app.post("/v1/shops/{shop_id}/diagnose", response_model=Diagnosis)
async def run_diagnosis(shop_id: str, accept_language: Optional[str] = Header(None)) -> Diagnosis:
    shop = _shop_or_404(shop_id)
    lang = i18n.norm(accept_language)
    if shop.lang != lang:
        shop.lang = lang
        store.save_shop(shop)
    diagnosis = await pipeline.diagnose(shop, lang)
    store.save_diagnosis(diagnosis)
    return diagnosis


@app.get("/v1/shops/{shop_id}/diagnosis", response_model=Diagnosis)
async def get_diagnosis(shop_id: str) -> Diagnosis:
    _shop_or_404(shop_id)
    d = store.load_diagnosis(shop_id)
    if d is None:
        raise HTTPException(404, "No diagnosis yet")
    return d


@app.post("/v1/shops/{shop_id}/doctor")
async def doctor(shop_id: str, req: ChatRequest, accept_language: Optional[str] = Header(None)) -> StreamingResponse:
    shop = _shop_or_404(shop_id)
    d = store.load_diagnosis(shop_id)
    if d is None:
        raise HTTPException(409, "Run a diagnosis first")
    if not req.messages or req.messages[-1].role != "user":
        raise HTTPException(422, "The last message must be from the user")
    return StreamingResponse(doctor_agent.chat(shop, d, req.messages, i18n.norm(accept_language)),
                             media_type="text/event-stream")


@app.post("/v1/shops/{shop_id}/experience", response_model=ExperienceAudit)
async def run_experience_check(shop_id: str, request: Request,
                               accept_language: Optional[str] = Header(None)) -> ExperienceAudit:
    """Multipart: optional `room` (RoomSummary JSON from the 3D scan) and `shot_<name>` photos."""
    shop = _shop_or_404(shop_id)
    lang = i18n.norm(accept_language)
    form = await request.form()

    room = None
    if isinstance(form.get("room"), str) and form["room"].strip():
        try:
            room = RoomSummary.model_validate_json(form["room"])
        except ValidationError as e:
            raise HTTPException(422, e.errors()) from e

    uploads = {key[5:]: f for key, f in form.multi_items() if key.startswith("shot_") and isinstance(f, StarletteUpload)}
    unknown = [s for s in uploads if s not in experience.SHOTS]
    if unknown:
        raise HTTPException(422, f"Unknown shots: {unknown}")
    missing = experience.missing_shots(list(uploads), has_scan=room is not None)
    if missing:
        raise HTTPException(422, {"missing_shots": missing})
    photos = {shot: (await _read([f]))[0] for shot, f in uploads.items()}

    if config.DEMO_MODE:
        audit = demo.sample_audit(shop.id, list(photos), with_scan=room is not None, lang=lang)
        if room is not None:  # a real scan in demo mode: keep the owner's room and measure it
            audit.room, audit.layout = room, experience.layout.measure(room)
            audit = experience.finalise(audit)
    else:
        try:
            audit = await experience.analyse(shop, room, photos, lang)
        except (anthropic.APIError, intake.llm.LLMError) as e:
            raise HTTPException(502, f"Couldn't analyse the shop: {e}") from e
    store.save_experience(audit)
    return audit


@app.get("/v1/shops/{shop_id}/experience", response_model=ExperienceAudit)
async def get_experience(shop_id: str) -> ExperienceAudit:
    _shop_or_404(shop_id)
    audit = store.load_experience(shop_id)
    if audit is None:
        raise HTTPException(404, "No shop experience check yet")
    return audit


@app.get("/v1/demo/room", response_model=RoomSummary)
async def demo_room() -> RoomSummary:
    """A sample scanned room, so the 3D view can be tried on devices without LiDAR (demo mode only)."""
    if not config.DEMO_MODE:
        raise HTTPException(404, "Demo mode only")
    return demo.sample_room()


# The web app (same origin as the API). Mounted last so the API routes above take precedence.
if WEB_DIR.exists():
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")
