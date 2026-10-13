"""12-month revenue projection as a low / expected / high band."""

import math
import statistics
from typing import List, Tuple

from . import config, i18n
from .schemas import Forecast, ForecastPoint, MonthValue


def add_months(month: str, n: int) -> str:
    y, m = map(int, month.split("-"))
    idx = y * 12 + (m - 1) + n
    return f"{idx // 12:04d}-{idx % 12 + 1:02d}"


def seasonal(month: str) -> float:
    return config.HK_SEASONALITY[int(month.split("-")[1]) - 1]


def _trend_and_volatility(history: List[MonthValue]) -> Tuple[float, float]:
    """Monthly growth rate and residual volatility from de-seasonalised log revenue."""
    if len(history) < 3:
        return 0.0, 0.10
    ys = [math.log(max(h.amount, 1.0) / seasonal(h.month)) for h in history]
    xs = list(range(len(ys)))
    x_bar, y_bar = statistics.mean(xs), statistics.mean(ys)
    slope = sum((x - x_bar) * (y - y_bar) for x, y in zip(xs, ys)) / sum((x - x_bar) ** 2 for x in xs)
    residuals = [y - (y_bar + slope * (x - x_bar)) for x, y in zip(xs, ys)]
    vol = statistics.pstdev(residuals) if len(residuals) > 2 else 0.10
    growth = math.exp(slope) - 1
    return max(-0.05, min(0.05, growth)), max(0.04, min(0.25, vol))


def project(history: List[MonthValue], health_overall: float, break_even: float,
            start_month: str, horizon: int = 12, lang: str = i18n.EN) -> Forecast:
    history = sorted(history, key=lambda h: h.month)
    trend, vol = _trend_and_volatility(history)

    # Healthier shops drift up, at-risk shops drift down: ±1%/month at the extremes.
    health_drift = (health_overall - 60) / 40 * 0.01
    monthly_growth = max(-0.06, min(0.06, trend + health_drift))

    if history:
        recent = history[-3:]
        base = statistics.mean(h.amount / seasonal(h.month) for h in recent)
        last_month = history[-1].month
    else:
        base, last_month = 0.0, add_months(start_month, -1)

    points = [ForecastPoint(month=h.month, low=h.amount, expected=h.amount, high=h.amount, is_actual=True)
              for h in history]
    for i in range(1, horizon + 1):
        month = add_months(last_month, i)
        expected = base * (1 + monthly_growth) ** i * seasonal(month)
        spread = vol * math.sqrt(i)
        points.append(ForecastPoint(
            month=month,
            low=round(expected * math.exp(-1.28 * spread), 0),  # ~10th percentile
            expected=round(expected, 0),
            high=round(expected * math.exp(1.28 * spread), 0),  # ~90th percentile
        ))

    future = [p for p in points if not p.is_actual]
    assumptions = [
        i18n.t(lang, "fc.history", n=len(history)) if history else i18n.t(lang, "fc.no_history"),
        i18n.t(lang, "fc.trend", t=f"{trend:+.1%}", h=f"{health_drift:+.1%}"),
        i18n.t(lang, "fc.season"),
        i18n.t(lang, "fc.band"),
    ]
    if len(history) < 3:
        assumptions.append(i18n.t(lang, "fc.short"))
    return Forecast(
        points=points,
        annual_expected=round(sum(p.expected for p in future), 0),
        trend_pct_monthly=round(monthly_growth, 4),
        break_even_revenue=round(break_even, 0),
        assumptions=assumptions,
    )
