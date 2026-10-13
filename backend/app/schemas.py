"""API data contracts shared by the backend and the iOS app (snake_case JSON)."""

from datetime import datetime, timezone
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ---------- Shop profile (what the owner tells us) ----------

class MonthValue(BaseModel):
    month: str  # "YYYY-MM"
    amount: float


class Costs(BaseModel):
    """Monthly operating costs in HKD."""
    rent: float = 0
    staff: float = 0
    ingredients: float = 0
    utilities: float = 0
    other: float = 0

    @property
    def total(self) -> float:
        return self.rent + self.staff + self.ingredients + self.utilities + self.other


class MenuItem(BaseModel):
    name: str
    price: Optional[float] = None
    section: Optional[str] = None


class MenuAnalysis(BaseModel):
    items: List[MenuItem] = []
    item_count: int = 0
    avg_price: Optional[float] = None
    median_price: Optional[float] = None
    price_min: Optional[float] = None
    price_max: Optional[float] = None
    clarity_score: float = Field(5, description="0-10: how easy the menu is to read and choose from")
    notes: List[str] = []


class ShopfrontAnalysis(BaseModel):
    signage_score: float = 5  # 0-10
    visibility_score: float = 5  # 0-10
    condition_score: float = 5  # 0-10
    appeal_score: float = 5  # 0-10
    observations: List[str] = []


class ShopInput(BaseModel):
    name: str
    category: str  # e.g. "cha chaan teng", "bubble tea", "hair salon"
    district: str  # e.g. "Mong Kok"
    address: Optional[str] = None
    lat: float
    lng: float
    opened_year: Optional[int] = None
    weekly_hours: Optional[float] = None
    monthly_revenue: List[MonthValue] = []
    costs: Costs = Costs()


class ShopProfile(ShopInput):
    id: str
    lang: str = "en"  # language the generated text was last written in
    menu: Optional[MenuAnalysis] = None
    shopfront: Optional[ShopfrontAnalysis] = None
    created_at: datetime = Field(default_factory=utcnow)


# ---------- Diagnosis (what ShopDoctor tells the owner) ----------

TwinStatus = Literal["survivor", "closed", "temporarily_closed"]


class TwinShop(BaseModel):
    id: str
    name: str
    address: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    status: TwinStatus
    source: Literal["google_places", "web", "sample"]
    rating: Optional[float] = None
    review_count: Optional[int] = None
    price_level: Optional[int] = None  # 0-4
    weekly_hours: Optional[float] = None
    photo_count: Optional[int] = None
    mtr_distance_m: Optional[float] = None
    distance_m: Optional[float] = None
    similarity: float = 0
    closed_note: Optional[str] = None
    source_url: Optional[str] = None


class SubScore(BaseModel):
    key: str
    label: str
    score: float  # 0-100
    weight: float
    explanation: str


class HealthScore(BaseModel):
    overall: float
    band: Literal["healthy", "watch", "at_risk"]
    subscores: List[SubScore]


class Finding(BaseModel):
    feature: str
    label: str
    unit: str
    owner: Optional[float]
    survivors_avg: Optional[float]
    closed_avg: Optional[float]
    verdict: Literal["like_survivors", "like_closed", "neutral"]
    gap: float  # normalised survivor-vs-closed gap, used for ranking
    message: str


class Comparison(BaseModel):
    survivor_count: int
    closed_count: int
    closure_rate: float
    survivor_similarity: float  # mean similarity to nearest survivors
    closed_similarity: float  # mean similarity to nearest closed shops
    nearest_survivor_ids: List[str]
    nearest_closed_ids: List[str]
    findings: List[Finding]


class ForecastPoint(BaseModel):
    month: str
    low: float
    expected: float
    high: float
    is_actual: bool = False


class Forecast(BaseModel):
    points: List[ForecastPoint]
    annual_expected: float
    trend_pct_monthly: float
    break_even_revenue: float
    assumptions: List[str]


class CostSlice(BaseModel):
    category: str
    amount: float


class Financials(BaseModel):
    revenue: float
    total_costs: float
    net_profit: float
    net_margin: float
    rent_ratio: float
    staff_ratio: float
    ingredient_ratio: float
    cost_breakdown: List[CostSlice]


class Prescription(BaseModel):
    title: str
    detail: str
    impact: Literal["high", "medium", "low"]
    evidence: str


class Diagnosis(BaseModel):
    shop_id: str
    generated_at: datetime = Field(default_factory=utcnow)
    health: HealthScore
    financials: Financials
    twins: List[TwinShop]
    comparison: Comparison
    forecast: Forecast
    prescriptions: List[Prescription] = []
    data_notes: List[str] = []


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]


# ---------- Shop experience (3D scan + photos) ----------

class PlanPoint(BaseModel):
    """A point on the floor plan, in metres. x/z follow RoomPlan's horizontal axes."""
    x: float
    z: float


class RoomElement(BaseModel):
    """A wall, door, window or opening, centred at (x, z) and rotated by angle_deg around the vertical."""
    id: str
    kind: Literal["wall", "door", "window", "opening"]
    x: float
    z: float
    width: float
    height: float = 0
    angle_deg: float = 0


class RoomObject(BaseModel):
    """A piece of furniture or equipment: a box of width × depth × height on the plan."""
    id: str
    category: str  # RoomPlan category: table, chair, sofa, storage, refrigerator, stove, sink, toilet, ...
    x: float
    z: float
    width: float
    depth: float
    height: float = 0.75
    angle_deg: float = 0


class RoomSummary(BaseModel):
    floor: List[PlanPoint] = []
    elements: List[RoomElement] = []
    objects: List[RoomObject] = []


class TightSpot(BaseModel):
    a: str
    b: str
    gap_m: float
    x: float
    z: float


class BlockedDoor(BaseModel):
    door_id: str
    object_ids: List[str]
    clearance_m: float


class LayoutMetrics(BaseModel):
    floor_area_m2: float
    tables: int
    seats: int
    m2_per_seat: Optional[float]
    narrowest_aisle_m: Optional[float]
    tight_spots: List[TightSpot] = []
    blocked_doors: List[BlockedDoor] = []
    dead_zone_share: float = 0  # share of the floor more than 1.5 m from any seat, table or counter


class SuggestedMove(BaseModel):
    object_id: str
    dx_m: float
    dz_m: float
    rotate_deg: float = 0


class ExperienceIssue(BaseModel):
    id: str
    area: str
    title: str
    observation: str
    why_it_matters: str
    steps: List[str]
    cost: Literal["low", "medium", "high"]
    effort: str
    impact: Literal["high", "medium", "low"]
    target: Optional[str] = None  # room element/object id, or "photo:<shot>"
    suggested_move: Optional[SuggestedMove] = None


class ExperienceArea(BaseModel):
    key: str
    label: str
    score: float  # 0-10
    strengths: List[str] = []


class ExperienceAudit(BaseModel):
    shop_id: str
    generated_at: datetime = Field(default_factory=utcnow)
    lang: str = "en"
    overall: float  # 0-100
    verdict: str
    areas: List[ExperienceArea]
    issues: List[ExperienceIssue]
    room: Optional[RoomSummary] = None
    layout: Optional[LayoutMetrics] = None
    shots: List[str] = []  # which photo shots were provided
    notes: List[str] = []
