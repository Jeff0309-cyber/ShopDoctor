import SwiftUI
import Charts
import MapKit

// MARK: - Revenue forecast

struct ForecastCard: View {
    let forecast: Forecast
    @State private var selected: Date?
    @State private var showAssumptions = false

    private var selectedPoint: ForecastPoint? {
        guard let selected else { return nil }
        return forecast.points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    /// The band starts at the last actual month so it visibly grows out of real data.
    private var bandPoints: [ForecastPoint] {
        let lastActual = forecast.points.last(where: \.isActual)
        return (lastActual.map { [$0] } ?? []) + forecast.points.filter { !$0.isActual }
    }

    var body: some View {
        Card {
            HStack(alignment: .top) {
                SectionTitle(title: L("Revenue forecast"), subtitle: L("Monthly, HKD · shaded band ≈ 80% of outcomes"),
                             icon: "chart.line.uptrend.xyaxis")
                Spacer()
                Button { showAssumptions.toggle() } label: { Image(systemName: "info.circle") }
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityLabel(L("Forecast assumptions"))
            }

            Chart {
                ForEach(bandPoints) { p in
                    AreaMark(x: .value("Month", p.date, unit: .month),
                             yStart: .value("Low", p.low), yEnd: .value("High", p.high))
                        .foregroundStyle(Theme.primary.opacity(0.14))
                        .interpolationMethod(.monotone)
                }
                ForEach(bandPoints) { p in
                    LineMark(x: .value("Month", p.date, unit: .month), y: .value("Expected", p.expected),
                             series: .value("Series", "Forecast"))
                        .foregroundStyle(Theme.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .interpolationMethod(.monotone)
                }
                ForEach(forecast.points.filter(\.isActual)) { p in
                    LineMark(x: .value("Month", p.date, unit: .month), y: .value("Actual", p.expected),
                             series: .value("Series", "Actual"))
                        .foregroundStyle(Theme.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Month", p.date, unit: .month), y: .value("Actual", p.expected))
                        .foregroundStyle(Theme.ink)
                        .symbolSize(40)
                }
                if forecast.breakEvenRevenue > 0 {
                    RuleMark(y: .value("Break-even", forecast.breakEvenRevenue))
                        .foregroundStyle(Theme.inkMuted)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(L("Break-even")).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                        }
                }
                if let p = selectedPoint {
                    RuleMark(x: .value("Selected", p.date, unit: .month))
                        .foregroundStyle(Theme.hairline)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ForecastTooltip(point: p)
                        }
                }
            }
            .chartXSelection(value: $selected)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(Fmt.hkd(v)).font(Theme.caption) }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 220)
            .padding(.top, 20)

            HStack(spacing: 16) {
                LegendSwatch(color: Theme.ink, label: L("Actual"))
                LegendSwatch(color: Theme.primary, label: L("Expected"), dashed: true)
                LegendSwatch(color: Theme.primary.opacity(0.25), label: L("Likely range"), block: true)
            }

            if showAssumptions {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(forecast.assumptions, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
                }
                .transition(.opacity)
            }
        }
    }
}

private struct ForecastTooltip: View {
    let point: ForecastPoint
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.date.formatted(.dateTime.month(.wide).year())).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            Text(Fmt.hkd(point.expected, compact: false)).font(Theme.number(15)).foregroundStyle(Theme.ink)
            if !point.isActual {
                Text("\(Fmt.hkd(point.low)) – \(Fmt.hkd(point.high))").font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            } else {
                Text(L("Actual")).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(8)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline))
        .shadow(color: Theme.ink.opacity(0.08), radius: 6, y: 2)
    }
}

struct LegendSwatch: View {
    let color: Color
    let label: String
    var dashed = false
    var block = false

    var body: some View {
        HStack(spacing: 6) {
            if block {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 10)
            } else {
                Path { p in p.move(to: .init(x: 0, y: 5)); p.addLine(to: .init(x: 16, y: 5)) }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 2] : []))
                    .frame(width: 16, height: 10)
            }
            Text(label).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
        }
    }
}

// MARK: - Survivors vs closed

/// One track per feature: where survivors sit, where closed shops sat, and where you are.
struct SurvivorsVsClosedCard: View {
    let comparison: Comparison

    var body: some View {
        Card {
            SectionTitle(
                title: L("Survivors vs closed"),
                subtitle: L("%lld still open · %lld closed nearby (%@ closure rate)",
                            comparison.survivorCount, comparison.closedCount, Fmt.pct(comparison.closureRate)),
                icon: "building.2"
            )
            HStack(spacing: 14) {
                MarkerLegend(kind: .survivor, label: L("Survivors avg"))
                MarkerLegend(kind: .closed, label: L("Closed avg"))
                MarkerLegend(kind: .you, label: L("You"))
            }
            if comparison.findings.isEmpty {
                EmptyHint(icon: "questionmark.circle", text: L("Not enough twin data to compare yet."))
            }
            ForEach(comparison.findings) { f in
                FindingTrack(finding: f)
            }
        }
    }
}

private struct FindingTrack: View {
    let finding: Finding

    private var values: [Double] { [finding.survivorsAvg, finding.closedAvg, finding.owner].compactMap { $0 } }

    private func position(_ v: Double, width: CGFloat) -> CGFloat {
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = max((hi - lo) * 0.25, abs(hi) * 0.05, 0.0001)
        return CGFloat((v - (lo - pad)) / ((hi + pad) - (lo - pad))) * width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(finding.label).font(Theme.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                switch finding.verdict {
                case .likeClosed: Pill(text: L("Like closed shops"), icon: "exclamationmark.triangle.fill", tint: Theme.warning)
                case .likeSurvivors: Pill(text: L("Like survivors"), icon: "checkmark", tint: Theme.primaryDark)
                case .neutral: EmptyView()
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface).frame(height: 6)
                    if let c = finding.closedAvg {
                        Marker(kind: .closed).position(x: position(c, width: geo.size.width), y: geo.size.height / 2)
                    }
                    if let s = finding.survivorsAvg {
                        Marker(kind: .survivor).position(x: position(s, width: geo.size.width), y: geo.size.height / 2)
                    }
                    if let o = finding.owner {
                        Marker(kind: .you).position(x: position(o, width: geo.size.width), y: geo.size.height / 2)
                    }
                }
            }
            .frame(height: 22)
            Text(finding.message).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(finding.message)
    }
}

enum MarkerKind { case survivor, closed, you }

/// Shape carries identity alongside colour: filled dot, hollow ring, ink diamond.
struct Marker: View {
    let kind: MarkerKind
    var size: CGFloat = 14

    var body: some View {
        switch kind {
        case .survivor:
            Circle().fill(Theme.survivor).frame(width: size, height: size)
                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
        case .closed:
            Circle().stroke(Theme.closed, lineWidth: 3).frame(width: size - 2, height: size - 2)
                .background(Circle().fill(Theme.background))
        case .you:
            RoundedRectangle(cornerRadius: 2).fill(Theme.you).frame(width: size - 3, height: size - 3)
                .rotationEffect(.degrees(45))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.background, lineWidth: 2).rotationEffect(.degrees(45)))
        }
    }
}

private struct MarkerLegend: View {
    let kind: MarkerKind
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Marker(kind: kind, size: 12)
            Text(label).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
        }
    }
}

// MARK: - Costs

struct CostCard: View {
    let financials: Financials

    private var slices: [CostSlice] { financials.costBreakdown.sorted { $0.amount > $1.amount } }

    var body: some View {
        Card {
            SectionTitle(title: L("Where the money goes"), subtitle: L("Monthly costs as a share of revenue"), icon: "banknote")
            if slices.isEmpty {
                EmptyHint(icon: "creditcard", text: L("Add your monthly costs to see this."))
            } else {
                Chart(slices) { s in
                    BarMark(x: .value("Amount", s.amount), y: .value("Category", s.category))
                        .foregroundStyle(Theme.primary)
                        .cornerRadius(4)
                        .annotation(position: .trailing) {
                            Text(label(for: s)).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in AxisValueLabel().font(Theme.caption).foregroundStyle(Theme.ink) }
                }
                .chartXScale(domain: 0...(Double(slices.first?.amount ?? 1) * 1.45))
                .frame(height: CGFloat(slices.count) * 38)

                HStack {
                    Text(L("Total %@ vs revenue %@", Fmt.hkd(financials.totalCosts), Fmt.hkd(financials.revenue)))
                        .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }

    private func label(for s: CostSlice) -> String {
        guard financials.revenue > 0 else { return Fmt.hkd(s.amount) }
        return "\(Fmt.hkd(s.amount)) · \(Fmt.pct(s.amount / financials.revenue))"
    }
}

// MARK: - Twin map

struct TwinMapCard: View {
    let shop: ShopProfile
    let diagnosis: Diagnosis

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: L("Your twins on the map"), subtitle: L("Similar shops within ~1.5 km"), icon: "map")
                HStack(spacing: 14) {
                    MarkerLegend(kind: .survivor, label: L("Still open"))
                    MarkerLegend(kind: .closed, label: L("Closed"))
                    MarkerLegend(kind: .you, label: L("You"))
                }
            }
            .padding([.horizontal, .top], 18)
            TwinMap(shop: shop, twins: diagnosis.twins)
                .frame(height: 260)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Theme.radius, bottomTrailingRadius: Theme.radius))
                .allowsHitTesting(false)
        }
    }
}

struct TwinMap: View {
    let shop: ShopProfile
    let twins: [TwinShop]
    var selection: Binding<String?>? = nil

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: shop.coordinate, latitudinalMeters: 3200, longitudinalMeters: 3200))) {
            ForEach(twins.filter { $0.coordinate != nil && $0.status != .temporarilyClosed }) { t in
                Annotation(t.name, coordinate: t.coordinate!, anchor: .center) {
                    Marker(kind: t.status == .survivor ? .survivor : .closed, size: selection?.wrappedValue == t.id ? 20 : 14)
                        .onTapGesture { selection?.wrappedValue = t.id }
                }
                .annotationTitles(.hidden)
            }
            Annotation(L("You"), coordinate: shop.coordinate, anchor: .center) {
                Marker(kind: .you, size: 20)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }
}
