import Foundation

// Mirrors the shop-experience part of backend/app/schemas.py. Plan coordinates are metres.

struct PlanPoint: Codable, Hashable {
    var x: Double
    var z: Double
}

struct RoomElement: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case wall, door, window, opening }
    var id: String
    var kind: Kind
    var x: Double
    var z: Double
    var width: Double
    var height: Double
    var angleDeg: Double
}

struct RoomObject: Codable, Hashable, Identifiable {
    var id: String
    var category: String
    var x: Double
    var z: Double
    var width: Double
    var depth: Double
    var height: Double
    var angleDeg: Double
}

struct RoomSummary: Codable, Hashable {
    var floor: [PlanPoint]
    var elements: [RoomElement]
    var objects: [RoomObject]

    var tableCount: Int { objects.filter { $0.category == "table" }.count }
    var floorArea: Double {
        guard floor.count >= 3 else { return 0 }
        let pts = floor + [floor[0]]
        return abs(zip(pts, pts.dropFirst()).reduce(0) { $0 + $1.0.x * $1.1.z - $1.1.x * $1.0.z }) / 2
    }
}

struct TightSpot: Codable, Hashable {
    var a: String
    var b: String
    var gapM: Double
    var x: Double
    var z: Double
}

struct BlockedDoor: Codable, Hashable {
    var doorId: String
    var objectIds: [String]
    var clearanceM: Double
}

struct LayoutMetrics: Codable, Hashable {
    var floorAreaM2: Double
    var tables: Int
    var seats: Int
    var m2PerSeat: Double?
    var narrowestAisleM: Double?
    var tightSpots: [TightSpot]
    var blockedDoors: [BlockedDoor]
    var deadZoneShare: Double
}

struct SuggestedMove: Codable, Hashable {
    var objectId: String
    var dxM: Double
    var dzM: Double
    var rotateDeg: Double
}

struct ExperienceIssue: Codable, Hashable, Identifiable {
    enum Level: String, Codable { case low, medium, high }
    var id: String
    var area: String
    var title: String
    var observation: String
    var whyItMatters: String
    var steps: [String]
    var cost: Level
    var effort: String
    var impact: Level
    var target: String?
    var suggestedMove: SuggestedMove?

    /// The photo this issue came from, if any ("photo:entrance" → "entrance").
    var photoShot: String? {
        guard let target, target.hasPrefix("photo:") else { return nil }
        return String(target.dropFirst(6))
    }

    /// The scanned object/door/wall this issue is pinned to, if any.
    var roomTarget: String? {
        guard let target, !target.hasPrefix("photo:") else { return nil }
        return target
    }
}

struct ExperienceArea: Codable, Hashable, Identifiable {
    var key: String
    var label: String
    var score: Double
    var strengths: [String]
    var id: String { key }
}

struct ExperienceAudit: Codable, Hashable {
    var shopId: String
    var generatedAt: String
    var overall: Double
    var verdict: String
    var areas: [ExperienceArea]
    var issues: [ExperienceIssue]
    var room: RoomSummary?
    var layout: LayoutMetrics?
    var shots: [String]
    var notes: [String]
}

/// The guided photos, in the order the owner takes them.
enum Shot: String, CaseIterable, Identifiable {
    case entrance, door, seating, table, ordering, washroom, atmosphere
    var id: String { rawValue }

    var title: String {
        switch self {
        case .entrance: L("Entrance from outside")
        case .door: L("First view from the door")
        case .seating: L("Seating area")
        case .table: L("A table set for service")
        case .ordering: L("Ordering and payment point")
        case .washroom: L("Washroom")
        case .atmosphere: L("Peak-hour atmosphere")
        }
    }

    var guideline: String {
        switch self {
        case .entrance: L("Stand across the street in daylight. Fit the whole frontage in.")
        case .door: L("Step just inside and shoot what a new customer sees first.")
        case .seating: L("From a corner, wide, with the walkways visible.")
        case .table: L("Chair height, with cutlery, sauces and menu as customers find them.")
        case .ordering: L("The counter or menu board, including any payment signs.")
        case .washroom: L("A wide shot, if customers use it.")
        case .atmosphere: L("During your busiest hour, lights as normal. No faces.")
        }
    }

    var icon: String {
        switch self {
        case .entrance: "storefront"
        case .door: "door.left.hand.open"
        case .seating: "chair.lounge"
        case .table: "fork.knife"
        case .ordering: "creditcard"
        case .washroom: "toilet"
        case .atmosphere: "lightbulb"
        }
    }

    /// With a 3D scan the layout is measured, so fewer photos are needed.
    static func required(withScan: Bool) -> [Shot] {
        withScan ? [.entrance, .table] : [.entrance, .door, .seating, .table]
    }

    static func shown(withScan: Bool) -> [Shot] {
        withScan ? [.entrance, .table, .ordering, .washroom] : allCases
    }
}
