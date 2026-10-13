import SwiftUI

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
            .shadow(color: Theme.ink.opacity(0.04), radius: 12, y: 4)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).foregroundStyle(Theme.primary) }
                Text(title).font(Theme.headline()).foregroundStyle(Theme.ink)
            }
            if let subtitle {
                Text(subtitle).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

struct Pill: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Theme.primary

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(Theme.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct StatusPill: View {
    let band: HealthBand
    var body: some View { Pill(text: band.label, icon: band.icon, tint: band.color) }
}

/// The app's primary action: a tactile, raised green button (see Kitchen.swift).
typealias PrimaryButtonStyle = TactileButtonStyle

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline(15))
            .foregroundStyle(Theme.primaryDark)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A single headline number with label; used in the KPI row.
struct StatTile: View {
    let label: String
    let value: String
    var detail: String? = nil
    var detailTint: Color = Theme.inkSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            Text(value).font(Theme.number(22)).foregroundStyle(Theme.ink).minimumScaleFactor(0.7).lineLimit(1)
            if let detail {
                Text(detail).font(Theme.caption).foregroundStyle(detailTint).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }
}

struct EmptyHint: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.inkMuted)
            Text(text).font(Theme.body).foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 8)
    }
}

enum Fmt {
    private static var chinese: Bool { Localization.current == .chinese }

    /// HK$ amounts. Compact form uses K/M in English and 萬 in Chinese (HK$17萬).
    static func hkd(_ v: Double, compact: Bool = true) -> String {
        if compact && chinese && abs(v) >= 10_000 {
            let wan = v / 10_000
            return "HK$" + wan.formatted(.number.precision(.fractionLength(0...(abs(wan) < 100 ? 1 : 0)))) + "萬"
        }
        if compact && abs(v) >= 1_000_000 { return String(format: "HK$%.1fM", v / 1_000_000) }
        if compact && abs(v) >= 10_000 { return String(format: "HK$%.0fK", v / 1_000) }
        return "HK$" + v.formatted(.number.precision(.fractionLength(0)))
    }

    static func pct(_ v: Double, signed: Bool = false) -> String {
        let s = (v * 100).formatted(.number.precision(.fractionLength(0))) + "%"
        return signed && v > 0 ? "+" + s : s
    }

    static func meters(_ v: Double) -> String {
        if chinese { return v >= 1000 ? String(format: "%.1f公里", v / 1000) : "\(Int(v))米" }
        return v >= 1000 ? String(format: "%.1f km", v / 1000) : "\(Int(v)) m"
    }
}
