"""Runtime settings and the tunable constants behind the scoring model."""

import os
from pathlib import Path


def _load_env_file(path: Path) -> None:
    """Read KEY=value lines from backend/.env (kept out of git) without overriding real env vars."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        key, sep, value = line.strip().partition("=")
        if sep and key and not key.startswith("#"):
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_env_file(Path(__file__).resolve().parent.parent / ".env")

MODEL = os.getenv("SHOPDOCTOR_MODEL", "claude-opus-5-5")
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# Which AI does the reading, writing and chatting: "anthropic" (Claude) or "gemini".
# Defaults to Gemini when only a Gemini key is configured.
AI_PROVIDER = os.getenv(
    "SHOPDOCTOR_AI_PROVIDER",
    "gemini" if GEMINI_API_KEY and not os.getenv("ANTHROPIC_API_KEY") else "anthropic",
)
# Tried in order; a model that is overloaded (503) or out of quota (429) falls through to the next.
GEMINI_MODELS = [m.strip() for m in os.getenv("GEMINI_MODELS", "gemini-flash-latest,gemini-flash-lite-latest").split(",") if m.strip()]

# Demo mode swaps every external call (Claude, Google Places) for deterministic
# sample data so the iOS app can be developed without API keys.
DEMO_MODE = os.getenv("SHOPDOCTOR_DEMO", "0") == "1"

DATA_DIR = Path(os.getenv("SHOPDOCTOR_DATA_DIR", Path(__file__).resolve().parent.parent / "data"))

# Twin discovery
TWIN_RADIUS_M = 1500
TWIN_MAX = 60
NEAREST_K = 5  # nearest closed / survivor twins used for the comparison

# Health Score sub-score weights (must sum to 1.0)
HEALTH_WEIGHTS = {
    "location": 0.15,
    "pricing": 0.15,
    "menu": 0.15,
    "visibility": 0.15,
    "financials": 0.25,
    "market": 0.15,
}

# Hong Kong small-business benchmarks (ratios of monthly revenue). These are
# rules of thumb used by HK F&B operators, not regulatory figures.
BENCHMARKS = {
    "rent_ratio_good": 0.15,
    "rent_ratio_bad": 0.30,
    "staff_ratio_good": 0.28,
    "staff_ratio_bad": 0.40,
    "ingredient_ratio_good": 0.32,
    "ingredient_ratio_bad": 0.42,
    "net_margin_good": 0.12,
    "net_margin_bad": -0.02,
    "mtr_good_m": 200,
    "mtr_bad_m": 900,
}

# Monthly demand index for HK street-level retail/F&B (Jan..Dec).
# Lunar New Year lift in Jan/Feb, summer typhoon/rain dip, Christmas peak.
# An assumption — replace with the shop's own history once 12+ months exist.
HK_SEASONALITY = [1.04, 1.06, 0.96, 0.98, 0.99, 0.95, 0.97, 0.96, 0.97, 1.01, 1.02, 1.09]

# Price elasticity of demand used by the Doctor's what-if tool.
PRICE_ELASTICITY = -0.6
