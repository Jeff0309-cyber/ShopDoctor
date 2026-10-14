"""Keep a public deployment from draining the AI quota.

Counts AI-backed requests (photo reading, diagnosis, Doctor chat, shop check) per visitor per
hour, plus an overall daily cap. In memory: fine for a single small server.
"""

import time
from collections import defaultdict, deque
from typing import Deque, Dict

from fastapi import Request
from fastapi.responses import JSONResponse

from . import config

HOUR, DAY = 3600, 86400

_per_ip: Dict[str, Deque[float]] = defaultdict(deque)
_all: Deque[float] = deque()


def is_ai_request(request: Request) -> bool:
    if request.method != "POST":
        return False
    path = request.url.path
    return path == "/v1/shops" or path.endswith(("/diagnose", "/doctor", "/experience"))


def client_ip(request: Request) -> str:
    # Behind Render's proxy the visitor's address is the first X-Forwarded-For entry.
    forwarded = request.headers.get("x-forwarded-for", "")
    return forwarded.split(",")[0].strip() or (request.client.host if request.client else "unknown")


def _trim(q: Deque[float], window: int, now: float) -> None:
    while q and now - q[0] > window:
        q.popleft()


def check(request: Request) -> "JSONResponse | None":
    """Returns a 429 response if this request is over a limit, else records it and returns None."""
    if config.DEMO_MODE or not is_ai_request(request):
        return None
    now = time.time()
    ip = client_ip(request)
    mine = _per_ip[ip]
    _trim(mine, HOUR, now)
    _trim(_all, DAY, now)
    if len(mine) >= config.AI_REQUESTS_PER_HOUR:
        return JSONResponse({"detail": "Too many requests from this device. Please try again in an hour."}, status_code=429)
    if len(_all) >= config.AI_REQUESTS_PER_DAY:
        return JSONResponse({"detail": "ShopDoctor is very busy today. Please try again tomorrow."}, status_code=429)
    mine.append(now)
    _all.append(now)
    return None
