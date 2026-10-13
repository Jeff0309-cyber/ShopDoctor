"""Find "twin" shops near the owner's shop with the Google Places API (New)."""

import math
from typing import Any, Dict, Iterable, List, Optional

import httpx

from . import config
from .schemas import ShopProfile, TwinShop

PLACES_URL = "https://places.googleapis.com/v1/places"
_FIELDS = ",".join(
    "places." + f
    for f in (
        "id", "displayName", "formattedAddress", "location", "businessStatus", "rating",
        "userRatingCount", "priceLevel", "regularOpeningHours", "photos", "primaryType",
    )
)
_PRICE_LEVELS = {
    "PRICE_LEVEL_FREE": 0,
    "PRICE_LEVEL_INEXPENSIVE": 1,
    "PRICE_LEVEL_MODERATE": 2,
    "PRICE_LEVEL_EXPENSIVE": 3,
    "PRICE_LEVEL_VERY_EXPENSIVE": 4,
}
_STATUS = {
    "OPERATIONAL": "survivor",
    "CLOSED_PERMANENTLY": "closed",
    "CLOSED_TEMPORARILY": "temporarily_closed",
}


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def weekly_hours(opening_hours: Optional[Dict[str, Any]]) -> Optional[float]:
    """Sum open hours across the week from Places `regularOpeningHours.periods`."""
    if not opening_hours or not opening_hours.get("periods"):
        return None
    total = 0.0
    for period in opening_hours["periods"]:
        start, end = period.get("open"), period.get("close")
        if start is None:
            continue
        if end is None:  # open 24 hours
            return 168.0
        start_min = start["day"] * 1440 + start.get("hour", 0) * 60 + start.get("minute", 0)
        end_min = end["day"] * 1440 + end.get("hour", 0) * 60 + end.get("minute", 0)
        if end_min <= start_min:
            end_min += 7 * 1440
        total += (end_min - start_min) / 60
    return round(min(total, 168.0), 1)


def price_level_from_avg(avg_price: Optional[float]) -> Optional[int]:
    """Map an average HKD menu price onto Google's 0-4 price scale."""
    if avg_price is None:
        return None
    for level, ceiling in enumerate((0, 60, 150, 400)):
        if avg_price <= ceiling:
            return max(level, 1)
    return 4


def parse_place(place: Dict[str, Any], origin_lat: float, origin_lng: float) -> Optional[TwinShop]:
    status = _STATUS.get(place.get("businessStatus", "OPERATIONAL"))
    loc = place.get("location") or {}
    if status is None or "latitude" not in loc:
        return None
    lat, lng = loc["latitude"], loc["longitude"]
    return TwinShop(
        id=place["id"],
        name=(place.get("displayName") or {}).get("text", "Unnamed"),
        address=place.get("formattedAddress"),
        lat=lat,
        lng=lng,
        status=status,
        source="google_places",
        rating=place.get("rating"),
        review_count=place.get("userRatingCount"),
        price_level=_PRICE_LEVELS.get(place.get("priceLevel", "")),
        weekly_hours=weekly_hours(place.get("regularOpeningHours")),
        photo_count=len(place.get("photos") or []),
        distance_m=round(haversine_m(origin_lat, origin_lng, lat, lng)),
    )


def nearest_station_m(lat: float, lng: float, stations: Iterable[Dict[str, float]]) -> Optional[float]:
    dists = [haversine_m(lat, lng, s["lat"], s["lng"]) for s in stations]
    return round(min(dists)) if dists else None


def is_self(shop: ShopProfile, twin: TwinShop) -> bool:
    """The owner's own listing would otherwise show up as its own twin."""
    if twin.lat is None or twin.lng is None:
        return False
    close = haversine_m(shop.lat, shop.lng, twin.lat, twin.lng) < 40
    return close and shop.name.strip().lower() in twin.name.lower()


async def _post(client: httpx.AsyncClient, path: str, body: Dict[str, Any], fields: str) -> Dict[str, Any]:
    response = await client.post(
        f"{PLACES_URL}:{path}",
        json=body,
        headers={"X-Goog-Api-Key": config.GOOGLE_MAPS_API_KEY, "X-Goog-FieldMask": fields},
        timeout=20,
    )
    response.raise_for_status()
    return response.json()


async def _text_search(client: httpx.AsyncClient, query: str, shop: ShopProfile) -> List[Dict[str, Any]]:
    places: List[Dict[str, Any]] = []
    body: Dict[str, Any] = {
        "textQuery": query,
        "pageSize": 20,
        "locationBias": {
            "circle": {"center": {"latitude": shop.lat, "longitude": shop.lng}, "radius": float(config.TWIN_RADIUS_M)}
        },
    }
    for _ in range(3):  # up to 60 results per query
        data = await _post(client, "searchText", body, _FIELDS + ",nextPageToken")
        places.extend(data.get("places", []))
        token = data.get("nextPageToken")
        if not token:
            break
        body["pageToken"] = token
    return places


async def _stations(client: httpx.AsyncClient, shop: ShopProfile) -> List[Dict[str, float]]:
    data = await _post(
        client,
        "searchNearby",
        {
            "includedTypes": ["subway_station"],
            "maxResultCount": 20,
            "locationRestriction": {
                "circle": {"center": {"latitude": shop.lat, "longitude": shop.lng}, "radius": 3000.0}
            },
        },
        "places.location",
    )
    return [
        {"lat": p["location"]["latitude"], "lng": p["location"]["longitude"]}
        for p in data.get("places", [])
        if "location" in p
    ]


class TwinSearch:
    def __init__(self, twins: List[TwinShop], own_listing: Optional[TwinShop], own_mtr_m: Optional[float]):
        self.twins = twins
        self.own_listing = own_listing  # the owner's shop as Google sees it, if listed
        self.own_mtr_m = own_mtr_m


async def find_twins(shop: ShopProfile) -> TwinSearch:
    queries = [
        f"{shop.category} in {shop.district}, Hong Kong",
        f"{shop.category} near {shop.address or shop.district}",
        f"{shop.name} {shop.district}",  # finds the owner's own listing
    ]
    async with httpx.AsyncClient() as client:
        raw: Dict[str, Dict[str, Any]] = {}
        for q in queries:
            for place in await _text_search(client, q, shop):
                raw.setdefault(place["id"], place)
        stations = await _stations(client, shop)

    twins: List[TwinShop] = []
    own: Optional[TwinShop] = None
    for place in raw.values():
        twin = parse_place(place, shop.lat, shop.lng)
        if twin is None or (twin.distance_m or 0) > config.TWIN_RADIUS_M * 1.5:
            continue
        twin.mtr_distance_m = nearest_station_m(twin.lat, twin.lng, stations)
        if is_self(shop, twin):
            own = twin
            continue
        twins.append(twin)
    twins.sort(key=lambda t: t.distance_m or 0)
    return TwinSearch(twins[: config.TWIN_MAX], own, nearest_station_m(shop.lat, shop.lng, stations))
