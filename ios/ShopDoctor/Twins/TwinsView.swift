import SwiftUI

struct TwinsView: View {
    @Environment(AppState.self) private var state
    @State private var filter: TwinStatus = .survivor
    @State private var selected: String?

    var body: some View {
        NavigationStack {
            if let d = state.diagnosis, let shop = state.shop {
                let rows = d.twins.filter { $0.status == filter }.sorted { $0.similarity > $1.similarity }
                ScrollViewReader { proxy in
                    List {
                        Section {
                            TwinMap(shop: shop, twins: d.twins, selection: $selected)
                                .frame(height: 240)
                                .listRowInsets(EdgeInsets())
                        }
                        Section {
                            Picker(L("Group"), selection: $filter) {
                                Text(L("Survivors (%lld)", d.comparison.survivorCount)).tag(TwinStatus.survivor)
                                Text(L("Closed (%lld)", d.comparison.closedCount)).tag(TwinStatus.closed)
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                        Section {
                            if rows.isEmpty {
                                EmptyHint(icon: "building.2", text: filter == .survivor ? L("No open twins found.") : L("No closed twins found."))
                            }
                            ForEach(rows) { t in
                                TwinRow(twin: t, highlighted: selected == t.id).id(t.id)
                            }
                        } header: {
                            Text(L("Most similar first")).font(Theme.caption)
                        }
                    }
                    .onChange(of: selected) { _, id in
                        guard let id, let twin = d.twin(id) else { return }
                        if twin.status != filter, twin.status != .temporarilyClosed { filter = twin.status }
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .navigationTitle(L("Twin shops"))
            }
        }
    }
}

private struct TwinRow: View {
    let twin: TwinShop
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Marker(kind: twin.status == .survivor ? .survivor : .closed, size: 10)
                Text(twin.name).font(Theme.body.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                Text(L("%lld%% match", Int(twin.similarity * 100))).font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primaryDark)
            }
            HStack(spacing: 12) {
                if let r = twin.rating { Label(String(format: "%.1f", r), systemImage: "star.fill") }
                if let n = twin.reviewCount { Label("\(n)", systemImage: "text.bubble") }
                if let p = twin.priceLevel { Text(String(repeating: "$", count: max(p, 1))) }
                if let d = twin.distanceM { Label(Fmt.meters(d), systemImage: "figure.walk") }
                if let h = twin.weeklyHours { Label(L("%lldh/wk", Int(h)), systemImage: "clock") }
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.inkSecondary)
            .labelStyle(CompactLabelStyle())
            if let note = twin.closedNote {
                Text(note).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            }
            if let url = twin.sourceUrl.flatMap(URL.init(string:)) {
                Link(L("Source"), destination: url).font(Theme.caption)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(highlighted ? Theme.primarySoft : Theme.background)
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.imageScale(.small); configuration.title }
    }
}
