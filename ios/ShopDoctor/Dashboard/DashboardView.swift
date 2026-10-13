import SwiftUI

/// Summary first: the score, today's one focus, then sections the owner opens when ready.
struct DashboardView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            ScrollView {
                if let d = state.diagnosis, let shop = state.shop {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shop.name).font(Theme.title()).foregroundStyle(Theme.ink)
                            Text(L("%@ · %@", L(shop.category), L(shop.district))).font(Theme.body).foregroundStyle(Theme.inkSecondary)
                        }
                        HealthHero(health: d.health)
                        FocusCard(diagnosis: d)

                        Text(L("Your check-up")).font(Theme.headline()).foregroundStyle(Theme.ink).padding(.top, 4)
                        SectionTiles(shop: shop, diagnosis: d)
                        ExperienceEntryCard(audit: state.experience)

                        Button { state.selectedTab = .doctor } label: {
                            Label(L("Ask the Doctor what to do next"), systemImage: "stethoscope")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        if !d.dataNotes.isEmpty {
                            NavigationLink {
                                DetailPage(title: L("About this data"), summary: L("Where these numbers come from and how far to trust them.")) {
                                    DataNotesCard(notes: d.dataNotes)
                                }
                            } label: {
                                Label(L("About this data"), systemImage: "info.circle")
                                    .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(Theme.gutter)
                }
            }
            .background(Theme.surface.opacity(0.5))
            .refreshable { await state.rediagnose() }
            .navigationTitle(L("Check-up"))
            .inlineNavigationTitle()
        }
    }
}

// MARK: - Hero

private struct HealthHero: View {
    let health: HealthScore

    private var verdict: String {
        switch health.band {
        case .healthy: L("In good shape. Keep doing what works.")
        case .watch: L("Doing OK, but a few areas need attention.")
        case .atRisk: L("Showing warning signs seen in shops that closed.")
        }
    }

    var body: some View {
        Card {
            HStack(spacing: 18) {
                ScoreRing(score: health.overall, size: 112, lineWidth: 11)
                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(band: health.band)
                    Text(verdict).font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// One thing to do, not three charts to read.
private struct FocusCard: View {
    let diagnosis: Diagnosis

    var body: some View {
        if let first = diagnosis.prescriptions.first {
            Card {
                Label(L("Today's focus"), systemImage: "scope")
                    .font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primaryDark)
                Text(first.title).font(Theme.headline()).foregroundStyle(Theme.ink)
                Text(first.detail).font(Theme.body).foregroundStyle(Theme.inkSecondary).lineLimit(3)
                NavigationLink {
                    PrescriptionPage(diagnosis: diagnosis)
                } label: {
                    HStack {
                        Text(L("View full prescription"))
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(Theme.headline(15)).foregroundStyle(Theme.primaryDark)
                }
            }
        }
    }
}

// MARK: - Section tiles

private struct SectionTiles: View {
    let shop: ShopProfile
    let diagnosis: Diagnosis

    var body: some View {
        let d = diagnosis
        let weakest = d.health.subscores.min { $0.score < $1.score }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            tile(icon: "pills.fill", title: L("Prescription"),
                 value: d.prescriptions.count == 1 ? L("1 step") : L("%lld steps", d.prescriptions.count),
                 caption: L("Signed by the Doctor"), tint: Theme.primaryDark) {
                PrescriptionPage(diagnosis: d)
            }
            tile(icon: "heart.text.square", title: L("Score breakdown"),
                 value: weakest.map { "\(Int($0.score))" } ?? "–",
                 caption: weakest.map { L("Weakest: %@", lowered($0.label)) } ?? "",
                 tint: weakest.map { HealthBand.forScore($0.score).color } ?? Theme.inkSecondary) {
                DetailPage(title: L("Score breakdown"), summary: L("Six vital signs, weighted into your Health Score. Lowest first.")) {
                    HealthCard(health: d.health)
                    SubscoreDetailCard(health: d.health)
                }
            }
            tile(icon: "banknote", title: L("Money"),
                 value: Fmt.pct(d.financials.netMargin),
                 caption: d.financials.netProfit >= 0 ? L("Net margin · profitable") : L("Net margin · losing money"),
                 tint: d.financials.netProfit >= 0 ? Theme.primaryDark : Theme.critical) {
                DetailPage(title: L("Money"), summary: moneySummary(d.financials)) {
                    KPIRow(financials: d.financials, forecast: d.forecast)
                    CostCard(financials: d.financials)
                }
            }
            tile(icon: "chart.line.uptrend.xyaxis", title: L("Forecast"),
                 value: Fmt.hkd(d.forecast.annualExpected),
                 caption: L("Next 12 months · %@/mo", Fmt.pct(d.forecast.trendPctMonthly, signed: true)),
                 tint: d.forecast.trendPctMonthly >= 0 ? Theme.primaryDark : Theme.critical) {
                DetailPage(title: L("Forecast"), summary: L("Where revenue is likely heading if nothing changes. Tap the chart to read a month.")) {
                    ForecastCard(forecast: d.forecast)
                }
            }
            tile(icon: "building.2", title: L("Survivors vs closed"),
                 value: Fmt.pct(d.comparison.closureRate),
                 caption: L("of similar shops nearby closed"),
                 tint: d.comparison.closureRate > 0.3 ? Theme.warning : Theme.primaryDark) {
                DetailPage(title: L("Survivors vs closed"), summary: compareSummary(d.comparison)) {
                    SurvivorsVsClosedCard(comparison: d.comparison)
                    TwinMapCard(shop: shop, diagnosis: d)
                }
            }
            tile(icon: "eye", title: L("What we saw"),
                 value: shop.menu.map { "\($0.itemCount)" } ?? "–",
                 caption: shop.menu == nil ? L("Add menu photos") : L("menu items read"),
                 tint: Theme.inkSecondary) {
                DetailPage(title: L("What we saw"), summary: L("What the Doctor read from your photos.")) {
                    PhotoFindingsCard(shop: shop)
                }
            }
        }
    }

    private func tile<Destination: View>(icon: String, title: String, value: String, caption: String, tint: Color,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            SectionTile(icon: icon, title: title, value: value, caption: caption, tint: tint)
        }
        .buttonStyle(TilePressStyle())
    }

    private func moneySummary(_ f: Financials) -> String {
        f.netProfit >= 0
            ? L("You keep %@ of every dollar of revenue. Here's where the rest goes.", Fmt.pct(f.netMargin))
            : L("Costs are above revenue by %@ a month. Here's where it goes.", Fmt.hkd(-f.netProfit))
    }

    private func compareSummary(_ c: Comparison) -> String {
        let flagged = c.findings.filter { $0.verdict == .likeClosed }.count
        switch flagged {
        case 0: return L("On every measure we could compare, you look like the shops that survived.")
        case 1: return L("On 1 measure, you look more like the shops that closed.")
        default: return L("On %lld measures, you look more like the shops that closed.", flagged)
        }
    }
}

private struct SectionTile: View {
    let icon: String
    let title: String
    let value: String
    let caption: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkMuted)
            }
            Text(title).font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            Text(value).font(Theme.number(22)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(Theme.caption).foregroundStyle(tint).lineLimit(2, reservesSpace: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.hairline))
        .shadow(color: Theme.ink.opacity(0.04), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
    }
}

private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The separate in-shop check: invites a first scan, or shows score and fix progress.
private struct ExperienceEntryCard: View {
    let audit: ExperienceAudit?

    var body: some View {
        NavigationLink { ExperienceHubView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Shop experience")).font(Theme.headline()).foregroundStyle(Theme.ink)
                    if let audit {
                        let fixed = ExperienceStore.done(for: audit).count
                        Text(L("%lld/100 · %lld of %lld fixes done", Int(audit.overall.rounded()), fixed, audit.issues.count))
                            .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                    } else {
                        Text(RoomScanner.isSupported ? L("Scan your shop in 3D and get a step-by-step fix plan")
                                                     : L("Photograph your shop and get a step-by-step fix plan"))
                            .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkMuted)
            }
            .padding(14)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.primary.opacity(0.35)))
            .shadow(color: Theme.ink.opacity(0.04), radius: 10, y: 3)
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Detail pages

/// A focused page: one plain-language sentence, then only the cards for that topic.
struct DetailPage<Content: View>: View {
    let title: String
    let summary: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(summary).font(Theme.body).foregroundStyle(Theme.inkSecondary)
                content
            }
            .padding(Theme.gutter)
        }
        .background(Theme.surface.opacity(0.5))
        .navigationTitle(title)
        .largeNavigationTitle()
    }
}

/// The signed slip, shown already printed (it prints once, right after the diagnosis).
private struct PrescriptionPage: View {
    @Environment(AppState.self) private var state
    let diagnosis: Diagnosis

    var body: some View {
        DetailPage(title: L("Prescription"), summary: L("The Doctor's top changes, most important first.")) {
            if let shop = state.shop {
                PrescriptionSlip(shop: shop, diagnosis: diagnosis)
            }
            Button { state.selectedTab = .doctor } label: {
                Label(L("Ask the Doctor about these"), systemImage: "stethoscope")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}

private struct PhotoFindingsCard: View {
    let shop: ShopProfile

    var body: some View {
        if shop.menu == nil && shop.shopfront == nil {
            Card { EmptyHint(icon: "camera", text: L("No photos analysed yet. Add menu and shopfront photos in a new check-up.")) }
        }
        if let menu = shop.menu {
            Card {
                SectionTitle(title: L("Menu"), subtitle: L("%lld items · clarity %lld/10", menu.itemCount, Int(menu.clarityScore)), icon: "menucard")
                if let avg = menu.avgPrice {
                    Text(L("Average price %@", Fmt.hkd(avg, compact: false))).font(Theme.body).foregroundStyle(Theme.ink)
                }
                ForEach(menu.notes, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
            }
        }
        if let front = shop.shopfront {
            Card {
                SectionTitle(title: L("Shopfront"), subtitle: L("As a passer-by sees it"), icon: "storefront")
                ForEach([(L("Signage"), front.signageScore), (L("Visibility"), front.visibilityScore),
                         (L("Condition"), front.conditionScore), (L("Walk-in appeal"), front.appealScore)], id: \.0) { name, score in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(name).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text("\(Int(score))/10").font(Theme.number(13)).foregroundStyle(Theme.ink)
                        }
                        ScoreBar(score: score * 10)
                    }
                }
                ForEach(front.observations, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
            }
        }
    }
}

// MARK: - Health

struct HealthCard: View {
    let health: HealthScore

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: 20) {
                ScoreRing(score: health.overall)
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Health Score")).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                    StatusPill(band: health.band)
                    if let weakest = health.subscores.min(by: { $0.score < $1.score }) {
                        Text(L("Weakest: %@", lowered(weakest.label)))
                            .font(Theme.body).foregroundStyle(Theme.ink)
                    }
                }
            }
            Divider().overlay(Theme.hairline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                ForEach(health.subscores) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon).font(.caption).foregroundStyle(Theme.inkSecondary)
                            Text(s.label).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text("\(Int(s.score))").font(Theme.number(14)).foregroundStyle(Theme.ink)
                        }
                        ScoreBar(score: s.score)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct KPIRow: View {
    let financials: Financials
    let forecast: Forecast

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            StatTile(label: L("Monthly revenue"), value: Fmt.hkd(financials.revenue),
                     detail: L("Break-even %@", Fmt.hkd(forecast.breakEvenRevenue)))
            StatTile(label: L("Net margin"), value: Fmt.pct(financials.netMargin),
                     detail: financials.netProfit >= 0 ? L("%@ profit", Fmt.hkd(financials.netProfit)) : L("%@ loss", Fmt.hkd(-financials.netProfit)),
                     detailTint: financials.netProfit >= 0 ? Theme.primaryDark : Theme.critical)
            StatTile(label: L("Rent / revenue"), value: Fmt.pct(financials.rentRatio),
                     detail: financials.rentRatio <= 0.2 ? L("Within HK norm") : L("Above 20% norm"),
                     detailTint: financials.rentRatio <= 0.2 ? Theme.primaryDark : Theme.warning)
            StatTile(label: L("Next 12 months"), value: Fmt.hkd(forecast.annualExpected),
                     detail: L("Trend %@/mo", Fmt.pct(forecast.trendPctMonthly, signed: true)),
                     detailTint: forecast.trendPctMonthly >= 0 ? Theme.primaryDark : Theme.critical)
        }
    }
}

// MARK: - Sub-score detail & notes

struct SubscoreDetailCard: View {
    let health: HealthScore

    var body: some View {
        Card {
            SectionTitle(title: L("How the score is built"), subtitle: L("Weighted sub-scores, 0–100"), icon: "list.bullet.clipboard")
            ForEach(health.subscores.sorted { $0.score < $1.score }) { s in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(s.label, systemImage: s.icon).font(Theme.body.weight(.semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(L("%lld · %lld%% weight", Int(s.score), Int(s.weight * 100))).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    Text(s.explanation).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct DataNotesCard: View {
    let notes: [String]
    var body: some View {
        Card {
            SectionTitle(title: L("About this data"), icon: "info.circle")
            ForEach(notes, id: \.self) { n in
                Label(n, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
            }
        }
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(Theme.inkMuted).frame(width: 4, height: 4).offset(y: -3)
            configuration.title.font(Theme.caption).foregroundStyle(Theme.inkSecondary)
        }
    }
}
