from app import forecast, scoring, twins
from app.doctor_agent import what_if
from app.pipeline import break_even_revenue
from app.schemas import Costs, MenuAnalysis, MonthValue, ShopProfile, TwinShop

MONG_KOK = (22.3193, 114.1694)


def make_shop(**kw) -> ShopProfile:
    base = dict(
        id="abc123", name="Wing Kee Café", category="cha chaan teng", district="Mong Kok",
        lat=MONG_KOK[0], lng=MONG_KOK[1], weekly_hours=63,
        monthly_revenue=[MonthValue(month=f"2026-0{m}", amount=a)
                         for m, a in zip(range(4, 10), [180_000, 176_000, 168_000, 171_000, 165_000, 160_000])],
        costs=Costs(rent=48_000, staff=55_000, ingredients=52_000, utilities=8_000, other=4_000),
    )
    base.update(kw)
    return ShopProfile(**base)


def twin(i, status, **kw) -> TwinShop:
    return TwinShop(id=f"t{i}", name=f"T{i}", status=status, source="sample", distance_m=300, **kw)


# ---------- Places parsing ----------

PLACE = {
    "id": "ChIJ123",
    "displayName": {"text": "Lotus Café"},
    "formattedAddress": "12 Sai Yeung Choi St S, Mong Kok",
    "location": {"latitude": 22.3200, "longitude": 114.1700},
    "businessStatus": "CLOSED_PERMANENTLY",
    "rating": 3.6,
    "userRatingCount": 88,
    "priceLevel": "PRICE_LEVEL_MODERATE",
    "photos": [{}, {}, {}],
    "regularOpeningHours": {"periods": [
        {"open": {"day": d, "hour": 7, "minute": 0}, "close": {"day": d, "hour": 21, "minute": 0}} for d in range(7)
    ]},
}


def test_parse_place_maps_status_price_and_hours():
    t = twins.parse_place(PLACE, *MONG_KOK)
    assert t.status == "closed"
    assert t.price_level == 2
    assert t.weekly_hours == 98
    assert t.photo_count == 3
    assert 50 < t.distance_m < 150


def test_weekly_hours_handles_overnight_and_24h():
    overnight = {"periods": [{"open": {"day": 5, "hour": 22}, "close": {"day": 6, "hour": 4}}]}
    assert twins.weekly_hours(overnight) == 6
    assert twins.weekly_hours({"periods": [{"open": {"day": 0, "hour": 0}}]}) == 168


def test_is_self_requires_name_and_proximity():
    shop = make_shop()
    me = TwinShop(id="x", name="Wing Kee Café (Mong Kok)", status="survivor", source="google_places",
                  lat=MONG_KOK[0], lng=MONG_KOK[1])
    assert twins.is_self(shop, me)
    me.lat += 0.01
    assert not twins.is_self(shop, me)


# ---------- comparison & health ----------

def group():
    survivors = [twin(i, "survivor", rating=4.4, review_count=900, weekly_hours=91, mtr_distance_m=150, price_level=1)
                 for i in range(6)]
    closed = [twin(10 + i, "closed", rating=3.5, review_count=60, weekly_hours=60, mtr_distance_m=800, price_level=2)
              for i in range(4)]
    return survivors + closed


def test_owner_like_closed_group_is_flagged():
    owner = {"rating": 3.6, "review_count": 80, "price_level": 2, "weekly_hours": 63,
             "mtr_distance_m": 750, "photo_count": None}
    comp = scoring.compare(owner, group())
    assert comp.closed_similarity > comp.survivor_similarity
    assert comp.closure_rate == 0.4
    assert comp.findings[0].verdict == "like_closed"
    assert {f.feature for f in comp.findings if f.verdict == "like_closed"} >= {"rating", "weekly_hours", "mtr_distance_m"}


def test_owner_like_survivors_scores_higher():
    weak = {"rating": 3.6, "review_count": 80, "price_level": 2, "weekly_hours": 63, "mtr_distance_m": 750, "photo_count": None}
    strong = {"rating": 4.4, "review_count": 1000, "price_level": 1, "weekly_hours": 91, "mtr_distance_m": 150, "photo_count": None}
    shop = make_shop()
    fin = scoring.financials(shop)
    scores = []
    for owner in (weak, strong):
        tw = group()
        comp = scoring.compare(owner, tw)
        scores.append(scoring.health_score(shop, owner, fin, comp, tw).overall)
    assert scores[1] > scores[0] + 10


def test_financials_use_last_three_months():
    fin = scoring.financials(make_shop())
    assert fin.revenue == round((171_000 + 165_000 + 160_000) / 3, 2)
    assert fin.total_costs == 167_000
    assert fin.net_profit < 0
    assert round(fin.rent_ratio, 2) == 0.29


def test_health_weights_sum_to_one_and_band():
    shop = make_shop(menu=MenuAnalysis(item_count=150, clarity_score=4))
    owner = scoring.owner_features(shop, None, 900)
    tw = group()
    h = scoring.health_score(shop, owner, scoring.financials(shop), scoring.compare(owner, tw), tw)
    assert abs(sum(s.weight for s in h.subscores) - 1) < 1e-9
    assert h.band == "at_risk"
    menu = next(s for s in h.subscores if s.key == "menu")
    assert menu.score == 25  # clarity 40 minus the long-menu penalty


def test_lin_is_monotonic_both_directions():
    assert scoring.lin(0.15, 0.15, 0.30) == 100
    assert scoring.lin(0.30, 0.15, 0.30) == 0
    assert scoring.lin(0.12, 0.12, -0.02) == 100
    assert scoring.lin(0.05, 0.12, -0.02) == 50


# ---------- forecast ----------

def test_forecast_band_and_trend():
    shop = make_shop()
    fc = forecast.project(shop.monthly_revenue, 45, 120_000, start_month="2026-10")
    future = [p for p in fc.points if not p.is_actual]
    assert len(future) == 12 and future[0].month == "2026-10"
    assert all(p.low < p.expected < p.high for p in future)
    widths = [(p.high - p.low) / p.expected for p in future]
    assert widths == sorted(widths)
    assert fc.trend_pct_monthly < 0  # declining revenue + weak health


def test_forecast_without_history():
    fc = forecast.project([], 70, 0, start_month="2026-10")
    assert fc.annual_expected == 0
    assert fc.points[0].month == "2026-10"


def test_add_months_wraps_year():
    assert forecast.add_months("2026-11", 3) == "2027-02"
    assert forecast.add_months("2026-01", -1) == "2025-12"


# ---------- what-if & break-even ----------

def test_rent_cut_improves_profit_one_for_one():
    r = what_if(make_shop(), {"rent_change_hkd": -6000})
    assert r["monthly_profit_change"] == 6000


def test_price_rise_with_inelastic_demand_raises_revenue():
    r = what_if(make_shop(), {"price_change_pct": 0.1})
    assert r["after"]["revenue"] > r["before"]["revenue"]


def test_break_even_treats_ingredients_as_variable():
    shop = make_shop()
    fixed = 48_000 + 55_000 + 8_000 + 4_000
    assert break_even_revenue(shop, 0) == fixed
    assert break_even_revenue(shop, 200_000) == fixed / (1 - 52_000 / 200_000)
