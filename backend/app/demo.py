"""Deterministic sample data for SHOPDOCTOR_DEMO=1 (no API keys needed).

All shop names are fictional so the sample never makes claims about real businesses.
"""

import math
import random
from typing import List

from . import i18n
from .schemas import MenuAnalysis, MenuItem, ShopfrontAnalysis, ShopProfile, TwinShop

_PREFIXES = ["Golden", "Lucky", "Jade", "Harbour", "Silver", "Red Lantern", "Lotus", "Pearl", "Dragon Gate",
             "Morning Star", "Bamboo", "Sunrise", "Kowloon", "Phoenix", "Plum Blossom", "Ocean"]
_SUFFIXES = ["Café", "Tea Room", "Kitchen", "Diner", "Corner", "House", "Eatery", "Restaurant"]


def sample_twins(shop: ShopProfile, n: int = 28, lang: str = i18n.EN) -> List[TwinShop]:
    rng = random.Random(f"{shop.lat:.4f},{shop.lng:.4f}")
    names = rng.sample([f"{p} {s}" for p in _PREFIXES for s in _SUFFIXES], n)
    twins = []
    for i, name in enumerate(names):
        closed = i % 3 == 0  # roughly a third closed, like a busy HK district
        angle, dist = rng.uniform(0, 2 * math.pi), rng.uniform(80, 1400)
        lat = shop.lat + dist * math.cos(angle) / 111_000
        lng = shop.lng + dist * math.sin(angle) / (111_000 * math.cos(math.radians(shop.lat)))
        twins.append(TwinShop(
            id=f"sample-{i}",
            name=f"{name} {i18n.t(lang, 'demo.sample')}",
            address=i18n.t(lang, "demo.street", n=rng.randint(1, 300), district=shop.district),
            lat=lat, lng=lng,
            status="closed" if closed else "survivor",
            source="sample",
            rating=round(rng.uniform(3.2, 3.9) if closed else rng.uniform(3.8, 4.6), 1),
            review_count=rng.randint(15, 260) if closed else rng.randint(120, 2400),
            price_level=rng.choice([2, 2, 3]) if closed else rng.choice([1, 1, 2]),
            weekly_hours=rng.choice([56, 63, 70]) if closed else rng.choice([77, 84, 91, 98]),
            photo_count=rng.randint(1, 5) if closed else rng.randint(6, 10),
            mtr_distance_m=round(rng.uniform(350, 1100) if closed else rng.uniform(60, 600)),
            distance_m=round(dist),
            closed_note=i18n.t(lang, "demo.closed", year=rng.choice(["2022", "2023", "2024", "2025"])) if closed else None,
        ))
    return twins


def sample_menu(lang: str = i18n.EN) -> MenuAnalysis:
    items = [
        MenuItem(name="Pineapple bun with butter", price=16, section="Bakery"),
        MenuItem(name="Milk tea", price=22, section="Drinks"),
        MenuItem(name="Yuen yeung", price=24, section="Drinks"),
        MenuItem(name="Macaroni soup with ham", price=38, section="Breakfast"),
        MenuItem(name="Baked pork chop rice", price=68, section="Rice"),
        MenuItem(name="French toast", price=32, section="Snacks"),
        MenuItem(name="Satay beef noodles", price=42, section="Noodles"),
        MenuItem(name="Curry fish balls", price=28, section="Snacks"),
    ]
    prices = [i.price for i in items]
    return MenuAnalysis(items=items, item_count=86, avg_price=round(sum(prices) / len(prices), 1),
                        median_price=30, price_min=16, price_max=68, clarity_score=5.5,
                        notes=[i18n.t(lang, "demo.menu_note")])


def sample_shopfront(lang: str = i18n.EN) -> ShopfrontAnalysis:
    return ShopfrontAnalysis(signage_score=5, visibility_score=6, condition_score=6, appeal_score=5,
                             observations=[i18n.t(lang, "demo.front_note")])


# ---------- sample shop-experience check ----------

def sample_room() -> "RoomSummary":
    """A fictional 9 m × 5 m cha chaan teng: one squeezed-in table and a rack by the door."""
    from .schemas import PlanPoint, RoomElement, RoomObject, RoomSummary

    objects = [
        RoomObject(id="counter", category="storage", x=8.4, z=2.5, width=3.0, depth=0.6, height=1.05, angle_deg=90),
        RoomObject(id="fridge", category="refrigerator", x=8.45, z=4.5, width=0.7, depth=0.7, height=1.8),
        RoomObject(id="rack", category="storage", x=1.0, z=0.9, width=0.8, depth=0.5, height=1.4),
    ]
    positions = [(2.6, 0.6), (4.6, 0.6), (6.6, 0.6),
                 (2.6, 2.5), (4.6, 2.5), (5.65, 2.5),   # table-6 is squeezed against table-5
                 (2.6, 4.4), (4.6, 4.4), (6.6, 4.4)]
    for n, (x, z) in enumerate(positions, 1):
        objects.append(RoomObject(id=f"table-{n}", category="table", x=x, z=z, width=0.75, depth=0.75))
        for side, dx in (("l", -0.6), ("r", 0.6)):
            objects.append(RoomObject(id=f"chair-{n}{side}", category="chair", x=x + dx, z=z,
                                      width=0.42, depth=0.42, height=0.85))
    return RoomSummary(
        floor=[PlanPoint(x=0, z=0), PlanPoint(x=9, z=0), PlanPoint(x=9, z=5), PlanPoint(x=0, z=5)],
        elements=[
            RoomElement(id="wall-front", kind="wall", x=4.5, z=0, width=9, height=3),
            RoomElement(id="wall-back", kind="wall", x=4.5, z=5, width=9, height=3),
            RoomElement(id="wall-left", kind="wall", x=0, z=2.5, width=5, height=3, angle_deg=90),
            RoomElement(id="wall-right", kind="wall", x=9, z=2.5, width=5, height=3, angle_deg=90),
            RoomElement(id="door-main", kind="door", x=1.0, z=0, width=0.9, height=2.1),
            RoomElement(id="window-front", kind="window", x=5.0, z=0, width=2.2, height=1.4),
        ],
        objects=objects,
    )


_SAMPLE_ISSUES = [
    dict(area="flow", target="rack", impact="high", cost="low", effort=("20 min", "20分鐘"),
         move=dict(object_id="rack", dx_m=-0.4, dz_m=3.5, rotate_deg=0),
         title=("Clear the doorway", "清空門口位置"),
         observation=("A storage rack sits 0.65 m inside the door, so customers squeeze past it on the way in.",
                      "門內0.65米處放置了儲物架，客人進門時要側身擠過。"),
         why=("The first two seconds decide whether a passer-by walks in; a cramped entrance reads as 'full'.",
              "路人在頭兩秒便決定是否入店；入口擠迫會令人以為店內已滿座。"),
         steps=(["Move the rack to the far corner (shown in green).", "Keep 1.2 m clear inside the door.",
                 "Put the daily specials board there instead, facing the street."],
                ["把儲物架移到店內最裏面的角落（綠色位置）。", "門內保留1.2米通道。", "改為在該處放置今日精選餐牌，面向街外。"])),
    dict(area="comfort", target="table-6", impact="high", cost="low", effort=("10 min", "10分鐘"),
         move=dict(object_id="table-6", dx_m=0.95, dz_m=0, rotate_deg=0),
         title=("Give the middle aisle room", "擴闊中間通道"),
         observation=("Table 6 is only 0.3 m from table 5, below the 0.9 m needed to pass with a tray.",
                      "6號枱與5號枱只相距0.3米，少於托盤通過所需的0.9米。"),
         why=("Staff and customers bump chairs here at peak hours, slowing service for the whole room.",
              "繁忙時間員工和客人會在此碰撞椅子，拖慢全店上菜速度。"),
         steps=(["Slide table 6 about 1 m towards the counter (shown in green).", "Check a tray fits between tables 5 and 6."],
                ["把6號枱向收銀處移約1米（綠色位置）。", "確認托盤能在5號與6號枱之間通過。"])),
    dict(area="first_impression", target="photo:entrance", impact="high", cost="medium", effort=("half a day", "半天"),
         move=None,
         title=("Light and translate the sign", "為招牌加燈及英文"),
         observation=("The shop sign is Chinese-only and unlit (sample data).", "招牌只有中文且沒有燈光（示例數據）。"),
         why=("After dark the shop disappears from the street, and tourists can't tell what it sells.",
              "入夜後店舖在街上幾乎看不見，遊客亦不知道店舖賣甚麼。"),
         steps=(["Add a warm LED strip under the sign.", "Add a short English line, e.g. 'Hong Kong Café · Milk Tea'."],
                ["在招牌下加裝暖色LED燈帶。", "加上簡短英文，例如「Hong Kong Café · Milk Tea」。"])),
    dict(area="ordering", target="photo:ordering", impact="medium", cost="low", effort=("15 min", "15分鐘"),
         move=None,
         title=("Show payment options at the till", "在收銀處展示付款方式"),
         observation=("No Octopus or QR payment sign is visible at the counter (sample data).",
                      "收銀處看不見八達通或二維碼付款標示（示例數據）。"),
         why=("Customers hesitate or queue longer when unsure how they can pay.", "客人不確定付款方式時會猶豫，令排隊時間更長。"),
         steps=(["Print one small sign with Octopus, PayMe, FPS and cash.", "Stick it at eye level next to the till."],
                ["印一張小告示，列出八達通、PayMe、轉數快及現金。", "貼在收銀機旁視線高度。"])),
    dict(area="table_setting", target="photo:table", impact="medium", cost="low", effort=("30 min", "30分鐘"),
         move=None,
         title=("Declutter the tables", "整理枱面"),
         observation=("Each table carries six sauce bottles and a menu stack, leaving little room for dishes (sample data).",
                      "每張枱放了六支醬料和一疊餐牌，放餐的空間不足（示例數據）。"),
         why=("Crowded tables feel less clean and slow down clearing between customers.", "枱面擠迫會顯得不整潔，亦拖慢翻枱。"),
         steps=(["Keep two sauces per table; bring others on request.", "Use one laminated menu per table."],
                ["每枱只留兩款醬料，其餘按需要提供。", "每枱只放一份過膠餐牌。"])),
]

_SAMPLE_AREAS = [
    ("first_impression", "First impression", "第一印象", 5), ("flow", "Flow & queueing", "人流及排隊", 4),
    ("comfort", "Comfort & spacing", "舒適度及空間", 5), ("table_setting", "Table setting", "餐枱擺設", 6),
    ("cleanliness", "Cleanliness", "清潔", 7), ("lighting", "Lighting & atmosphere", "燈光及氣氛", 6),
    ("ordering", "Ordering & payment", "點餐及付款", 6), ("accessibility", "Accessibility", "無障礙", 5),
]


def sample_audit(shop_id: str, shots: List[str], with_scan: bool, lang: str = i18n.EN) -> "ExperienceAudit":
    from . import experience, layout
    from .schemas import ExperienceArea, ExperienceAudit, ExperienceIssue, SuggestedMove

    zh = lang == i18n.ZH
    pick = (lambda pair: pair[1] if zh else pair[0])
    room = sample_room() if with_scan else None
    issues = []
    for d in _SAMPLE_ISSUES:
        if not with_scan and not d["target"].startswith("photo:"):
            continue
        issues.append(ExperienceIssue(
            id="", area=d["area"], title=pick(d["title"]), observation=pick(d["observation"]),
            why_it_matters=pick(d["why"]), steps=pick(d["steps"]), cost=d["cost"], effort=pick(d["effort"]),
            impact=d["impact"], target=d["target"],
            suggested_move=SuggestedMove(**d["move"]) if d["move"] else None,
        ))
    audit = ExperienceAudit(
        shop_id=shop_id, lang=lang, overall=58,
        verdict=("店面大致整潔，但入口和通道擠迫，令客人卻步。（示例數據）" if zh
                 else "Clean and cheerful, but a cramped entrance and aisle hold it back. (sample data)"),
        areas=[ExperienceArea(key=k, label=zh_l if zh else en_l, score=s, strengths=[]) for k, en_l, zh_l, s in _SAMPLE_AREAS],
        issues=issues, room=room, layout=layout.measure(room) if room else None, shots=shots,
        notes=[i18n.t(lang, "note.demo")],
    )
    return experience.finalise(audit)
