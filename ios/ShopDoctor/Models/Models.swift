import Foundation
import CoreLocation

// Mirrors backend/app/schemas.py. JSON is snake_case; the coders convert.

struct MonthValue: Codable, Hashable, Identifiable {
    var month: String  // "YYYY-MM"
    var amount: Double
    var id: String { month }
}

struct Costs: Codable, Hashable {
    var rent: Double = 0
    var staff: Double = 0
    var ingredients: Double = 0
    var utilities: Double = 0
    var other: Double = 0
    var total: Double { rent + staff + ingredients + utilities + other }
}

struct MenuItem: Codable, Hashable {
    var name: String
    var price: Double?
    var section: String?
}

struct MenuAnalysis: Codable, Hashable {
    var items: [MenuItem]
    var itemCount: Int
    var avgPrice: Double?
    var medianPrice: Double?
    var priceMin: Double?
    var priceMax: Double?
    var clarityScore: Double
    var notes: [String]
}

struct ShopfrontAnalysis: Codable, Hashable {
    var signageScore: Double
    var visibilityScore: Double
    var conditionScore: Double
    var appealScore: Double
    var observations: [String]
}

struct ShopInput: Codable, Hashable {
    var name: String
    var category: String
    var district: String
    var address: String?
    var lat: Double
    var lng: Double
    var openedYear: Int?
    var weeklyHours: Double?
    var monthlyRevenue: [MonthValue]
    var costs: Costs
}

struct ShopProfile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var category: String
    var district: String
    var address: String?
    var lat: Double
    var lng: Double
    var openedYear: Int?
    var weeklyHours: Double?
    var monthlyRevenue: [MonthValue]
    var costs: Costs
    var menu: MenuAnalysis?
    var shopfront: ShopfrontAnalysis?

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }

    var input: ShopInput {
        ShopInput(name: name, category: category, district: district, address: address, lat: lat, lng: lng,
                  openedYear: openedYear, weeklyHours: weeklyHours, monthlyRevenue: monthlyRevenue, costs: costs)
    }
}

enum TwinStatus: String, Codable {
    case survivor, closed, temporarilyClosed = "temporarily_closed"

    var label: String {
        switch self {
        case .survivor: L("Still open")
        case .closed: L("Closed")
        case .temporarilyClosed: L("Temporarily closed")
        }
    }
}

struct TwinShop: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var address: String?
    var lat: Double?
    var lng: Double?
    var status: TwinStatus
    var source: String
    var rating: Double?
    var reviewCount: Int?
    var priceLevel: Int?
    var weeklyHours: Double?
    var photoCount: Int?
    var mtrDistanceM: Double?
    var distanceM: Double?
    var similarity: Double
    var closedNote: String?
    var sourceUrl: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return .init(latitude: lat, longitude: lng)
    }
}

struct SubScore: Codable, Hashable, Identifiable {
    var key: String
    var label: String
    var score: Double
    var weight: Double
    var explanation: String
    var id: String { key }

    var icon: String {
        switch key {
        case "location": "mappin.and.ellipse"
        case "pricing": "tag"
        case "menu": "menucard"
        case "visibility": "eye"
        case "financials": "banknote"
        case "market": "chart.line.uptrend.xyaxis"
        default: "circle"
        }
    }
}

struct HealthScore: Codable, Hashable {
    var overall: Double
    var band: HealthBand
    var subscores: [SubScore]
}

enum Verdict: String, Codable {
    case likeSurvivors = "like_survivors", likeClosed = "like_closed", neutral
}

struct Finding: Codable, Hashable, Identifiable {
    var feature: String
    var label: String
    var unit: String
    var owner: Double?
    var survivorsAvg: Double?
    var closedAvg: Double?
    var verdict: Verdict
    var gap: Double
    var message: String
    var id: String { feature }
}

struct Comparison: Codable, Hashable {
    var survivorCount: Int
    var closedCount: Int
    var closureRate: Double
    var survivorSimilarity: Double
    var closedSimilarity: Double
    var nearestSurvivorIds: [String]
    var nearestClosedIds: [String]
    var findings: [Finding]
}

struct ForecastPoint: Codable, Hashable, Identifiable {
    var month: String
    var low: Double
    var expected: Double
    var high: Double
    var isActual: Bool
    var id: String { month }

    var date: Date { Self.parser.date(from: month) ?? .distantPast }

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

struct Forecast: Codable, Hashable {
    var points: [ForecastPoint]
    var annualExpected: Double
    var trendPctMonthly: Double
    var breakEvenRevenue: Double
    var assumptions: [String]
}

struct CostSlice: Codable, Hashable, Identifiable {
    var category: String
    var amount: Double
    var id: String { category }
}

struct Financials: Codable, Hashable {
    var revenue: Double
    var totalCosts: Double
    var netProfit: Double
    var netMargin: Double
    var rentRatio: Double
    var staffRatio: Double
    var ingredientRatio: Double
    var costBreakdown: [CostSlice]
}

enum Impact: String, Codable { case high, medium, low }

struct Prescription: Codable, Hashable, Identifiable {
    var title: String
    var detail: String
    var impact: Impact
    var evidence: String
    var id: String { title }
}

struct Diagnosis: Codable, Hashable {
    var shopId: String
    var generatedAt: String
    var health: HealthScore
    var financials: Financials
    var twins: [TwinShop]
    var comparison: Comparison
    var forecast: Forecast
    var prescriptions: [Prescription]
    var dataNotes: [String]

    func twin(_ id: String) -> TwinShop? { twins.first { $0.id == id } }
}

struct ChatMessage: Codable, Hashable, Identifiable {
    enum Role: String, Codable { case user, assistant }
    var role: Role
    var content: String
    var id = UUID()

    enum CodingKeys: String, CodingKey { case role, content }
}
