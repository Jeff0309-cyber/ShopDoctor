import SwiftUI

/// Design tokens. Retune the whole app's look from this one file.
enum Theme {
    // Surfaces
    static let background = Color(hex: 0xFFFFFF)
    static let surface = Color(hex: 0xF6F9F7)
    static let hairline = Color(hex: 0xE4EBE7)

    // Brand
    static let primary = Color(hex: 0x0E9F5B)
    static let primaryDark = Color(hex: 0x0A7A45)
    static let primarySoft = Color(hex: 0xE7F6EE)

    // Text
    static let ink = Color(hex: 0x0F172A)
    static let inkSecondary = Color(hex: 0x5B6472)
    static let inkMuted = Color(hex: 0x8A94A0)

    // Status (reserved: always shown with an icon + label)
    static let good = primary
    static let warning = Color(hex: 0xD97706)
    static let critical = Color(hex: 0xDC2626)

    // Chart roles (validated: survivor vs closed ΔE ≥ 8.7 under all CVD types)
    static let survivor = primary
    static let closed = Color(hex: 0x8A94A0)
    static let you = ink

    // Geometry
    static let radius: CGFloat = 20
    static let radiusSmall: CGFloat = 12
    static let gutter: CGFloat = 16
    static let spacing: CGFloat = 12

    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
    static let body = Font.system(size: 15, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum HealthBand: String, Codable {
    case healthy, watch, atRisk = "at_risk"

    var label: String {
        switch self {
        case .healthy: L("Healthy")
        case .watch: L("Needs attention")
        case .atRisk: L("At risk")
        }
    }

    var color: Color {
        switch self {
        case .healthy: Theme.good
        case .watch: Theme.warning
        case .atRisk: Theme.critical
        }
    }

    var icon: String {
        switch self {
        case .healthy: "checkmark.seal.fill"
        case .watch: "exclamationmark.triangle.fill"
        case .atRisk: "cross.case.fill"
        }
    }

    static func forScore(_ score: Double) -> HealthBand {
        score >= 75 ? .healthy : score >= 55 ? .watch : .atRisk
    }
}
