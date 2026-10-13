from app import demo, layout
from app.schemas import PlanPoint, RoomObject, RoomSummary, SuggestedMove


def box(id, cat, x, z, w=0.8, d=0.8, angle=0):
    return RoomObject(id=id, category=cat, x=x, z=z, width=w, depth=d, angle_deg=angle)


def test_sample_room_measurements():
    m = layout.measure(demo.sample_room())
    assert m.floor_area_m2 == 45.0
    assert m.tables == 9 and m.seats == 18 and m.m2_per_seat == 2.5
    assert m.narrowest_aisle_m == 0.3
    assert (m.tight_spots[0].a, m.tight_spots[0].b) == ("table-5", "table-6")
    assert m.blocked_doors[0].door_id == "door-main" and "rack" in m.blocked_doors[0].object_ids


def test_back_of_house_gaps_are_not_aisles():
    room = RoomSummary(floor=[PlanPoint(x=0, z=0), PlanPoint(x=5, z=0), PlanPoint(x=5, z=5), PlanPoint(x=0, z=5)],
                       objects=[box("fridge", "refrigerator", 1, 1), box("counter", "storage", 2, 1)])
    assert layout.measure(room).tight_spots == []


def test_gap_and_rotation():
    a = layout.footprint(box("a", "table", 0, 0, 1, 1))
    b = layout.footprint(box("b", "table", 2, 0, 1, 1))
    assert abs(layout.gap(a, b) - 1.0) < 1e-9
    rotated = layout.footprint(box("c", "table", 2, 0, 1, 1, angle=45))  # corner now points at a
    assert layout.gap(a, rotated) < 1.0
    assert layout.gap(a, layout.footprint(box("d", "table", 0.5, 0, 1, 1))) == 0.0


def test_point_inside_footprint_has_zero_distance():
    rect = layout.footprint(box("t", "table", 1, 1, 1, 1))
    assert layout.point_gap((1, 1), rect) == 0.0
    assert abs(layout.point_gap((3, 1), rect) - 1.5) < 1e-9


def test_suggested_moves_are_validated():
    room = demo.sample_room()
    assert layout.move_is_valid(room, SuggestedMove(object_id="table-6", dx_m=0.95, dz_m=0))
    assert not layout.move_is_valid(room, SuggestedMove(object_id="table-6", dx_m=-1.05, dz_m=0))  # onto table-5
    assert not layout.move_is_valid(room, SuggestedMove(object_id="table-6", dx_m=0, dz_m=5))  # off the floor
    assert not layout.move_is_valid(room, SuggestedMove(object_id="ghost", dx_m=0, dz_m=0))


def test_dead_zone_share_grows_in_empty_room():
    floor = [PlanPoint(x=0, z=0), PlanPoint(x=10, z=0), PlanPoint(x=10, z=10), PlanPoint(x=0, z=10)]
    crowded = RoomSummary(floor=floor, objects=[box(f"t{i}{j}", "table", 1 + 2.5 * i, 1 + 2.5 * j) for i in range(4) for j in range(4)])
    sparse = RoomSummary(floor=floor, objects=[box("t", "table", 1, 1)])
    assert layout.measure(sparse).dead_zone_share > 0.8
    assert layout.measure(crowded).dead_zone_share < 0.1
