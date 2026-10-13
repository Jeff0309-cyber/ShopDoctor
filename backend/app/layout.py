"""Measure a scanned room: seats, space per seat, aisle gaps, blocked doors, dead zones.

Pure geometry on the floor plan (metres), so it is unit-testable without a scan.
"""

import math
from itertools import combinations
from typing import List, Optional, Sequence, Tuple

from .schemas import BlockedDoor, LayoutMetrics, RoomObject, RoomSummary, SuggestedMove, TightSpot

Pt = Tuple[float, float]

SEATING = {"chair", "sofa"}
CUSTOMER_FURNITURE = {"table", "sofa"}
SURFACES = {"table", "storage", "refrigerator", "stove", "sink", "oven", "dishwasher"}  # "storage" ≈ counters
AISLE_MIN_M = 0.9  # comfortable passing width between furniture
DOOR_CLEAR_M = 1.2
DEAD_ZONE_M = 1.5
SOFA_SEAT_M = 0.6


# ---------- primitives ----------

def footprint(o: RoomObject, dx: float = 0, dz: float = 0, rotate_deg: float = 0) -> List[Pt]:
    """Corners of the object's rotated rectangle on the plan."""
    a = math.radians(o.angle_deg + rotate_deg)
    c, s = math.cos(a), math.sin(a)
    hw, hd = o.width / 2, o.depth / 2
    cx, cz = o.x + dx, o.z + dz
    return [(cx + px * c - pz * s, cz + px * s + pz * c) for px, pz in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))]


def polygon_area(poly: Sequence[Pt]) -> float:
    return abs(sum(x1 * z2 - x2 * z1 for (x1, z1), (x2, z2) in zip(poly, list(poly[1:]) + [poly[0]]))) / 2


def point_in_polygon(p: Pt, poly: Sequence[Pt]) -> bool:
    x, z = p
    inside = False
    for (x1, z1), (x2, z2) in zip(poly, list(poly[1:]) + [poly[0]]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            inside = not inside
    return inside


def _point_segment(p: Pt, a: Pt, b: Pt) -> float:
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    if dx == dz == 0:
        return math.dist(p, a)
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / (dx * dx + dz * dz)))
    return math.dist(p, (ax + t * dx, az + t * dz))


def _edges(poly: Sequence[Pt]):
    return list(zip(poly, list(poly[1:]) + [poly[0]]))


def polygons_overlap(p: Sequence[Pt], q: Sequence[Pt]) -> bool:
    """Separating-axis test for convex polygons (rectangles here)."""
    for poly in (p, q):
        for (x1, z1), (x2, z2) in _edges(poly):
            nx, nz = z1 - z2, x2 - x1
            pa = [nx * x + nz * z for x, z in p]
            qa = [nx * x + nz * z for x, z in q]
            if max(pa) <= min(qa) + 1e-9 or max(qa) <= min(pa) + 1e-9:
                return False
    return True


def gap(p: Sequence[Pt], q: Sequence[Pt]) -> float:
    """Shortest distance between two convex footprints (0 when they touch or overlap)."""
    if polygons_overlap(p, q):
        return 0.0
    d = min(_point_segment(v, a, b) for v in p for a, b in _edges(q))
    return min(d, min(_point_segment(v, a, b) for v in q for a, b in _edges(p)))


def point_gap(p: Pt, poly: Sequence[Pt]) -> float:
    """Distance from a point to a footprint (0 inside it)."""
    if point_in_polygon(p, poly):
        return 0.0
    return min(_point_segment(p, a, b) for a, b in _edges(poly))


def _closest_midpoint(p: Sequence[Pt], q: Sequence[Pt]) -> Pt:
    a = min(p, key=lambda v: min(math.dist(v, w) for w in q))
    b = min(q, key=lambda w: math.dist(a, w))
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


# ---------- metrics ----------

def measure(room: RoomSummary) -> LayoutMetrics:
    floor = [(p.x, p.z) for p in room.floor]
    area = polygon_area(floor) if len(floor) >= 3 else 0.0
    objs = room.objects

    tables = sum(1 for o in objs if o.category == "table")
    seats = sum(1 for o in objs if o.category == "chair")
    seats += sum(max(1, int(o.width // SOFA_SEAT_M)) for o in objs if o.category == "sofa")

    # Aisles: gaps between neighbouring furniture that customers walk past. Chairs tuck in, so they're
    # left out, and gaps between two pieces of back-of-house equipment aren't customer aisles.
    big = [(o, footprint(o)) for o in objs if o.category != "chair"]
    tight: List[TightSpot] = []
    narrowest: Optional[float] = None
    for (a, pa), (b, pb) in combinations(big, 2):
        if not ({a.category, b.category} & CUSTOMER_FURNITURE):
            continue
        g = gap(pa, pb)
        if g <= 0.05 or g > 2.0:  # touching (a deliberate run) or not neighbours
            continue
        narrowest = g if narrowest is None else min(narrowest, g)
        if g < AISLE_MIN_M:
            mx, mz = _closest_midpoint(pa, pb)
            tight.append(TightSpot(a=a.id, b=b.id, gap_m=round(g, 2), x=round(mx, 2), z=round(mz, 2)))
    tight.sort(key=lambda t: t.gap_m)

    blocked: List[BlockedDoor] = []
    for door in (e for e in room.elements if e.kind == "door"):
        near = [(o.id, point_gap((door.x, door.z), footprint(o))) for o in objs]
        near = [(i, d) for i, d in near if d < DOOR_CLEAR_M]
        if near:
            blocked.append(BlockedDoor(door_id=door.id, object_ids=[i for i, _ in near],
                                       clearance_m=round(min(d for _, d in near), 2)))

    return LayoutMetrics(
        floor_area_m2=round(area, 1),
        tables=tables,
        seats=seats,
        m2_per_seat=round(area / seats, 2) if seats else None,
        narrowest_aisle_m=round(narrowest, 2) if narrowest is not None else None,
        tight_spots=tight[:8],
        blocked_doors=blocked,
        dead_zone_share=round(_dead_zone_share(floor, objs), 2),
    )


def _dead_zone_share(floor: List[Pt], objs: List[RoomObject], step: float = 0.25) -> float:
    """Share of floor further than DEAD_ZONE_M from any seat, table or counter."""
    anchors = [footprint(o) for o in objs if o.category in SEATING | SURFACES]
    if len(floor) < 3 or not anchors:
        return 0.0
    xs, zs = [p[0] for p in floor], [p[1] for p in floor]
    total = dead = 0
    x = min(xs) + step / 2
    while x < max(xs):
        z = min(zs) + step / 2
        while z < max(zs):
            if point_in_polygon((x, z), floor):
                total += 1
                if all(point_gap((x, z), a) > DEAD_ZONE_M for a in anchors):
                    dead += 1
            z += step
        x += step
    return dead / total if total else 0.0


# ---------- validating the AI's suggestions ----------

def move_is_valid(room: RoomSummary, move: SuggestedMove) -> bool:
    """A suggested move must keep the object on the floor and clear of other furniture."""
    obj = next((o for o in room.objects if o.id == move.object_id), None)
    if obj is None or (abs(move.dx_m) > 6 or abs(move.dz_m) > 6):
        return False
    moved = footprint(obj, move.dx_m, move.dz_m, move.rotate_deg)
    floor = [(p.x, p.z) for p in room.floor]
    if len(floor) >= 3 and not all(point_in_polygon(c, floor) for c in moved):
        return False
    for other in room.objects:
        if other.id == obj.id or other.category == "chair":
            continue
        if polygons_overlap(moved, footprint(other)):
            return False
    return True
