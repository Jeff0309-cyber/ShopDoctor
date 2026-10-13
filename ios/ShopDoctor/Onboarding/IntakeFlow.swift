import SwiftUI
import PhotosUI
import MapKit
import UniformTypeIdentifiers

/// The "check-up form": four short steps, then the diagnosis runs.
struct IntakeFlow: View {
    @Environment(AppState.self) private var state
    @State private var draft = IntakeDraft()
    @State private var step = 0

    private let steps = ["Your shop", "Photos", "Money", "Location"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0: BasicsStep(draft: $draft)
                    case 1: PhotosStep(draft: $draft)
                    case 2: MoneyStep(draft: $draft)
                    default: LocationStep(draft: $draft)
                    }
                }
                .padding(Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cross.case.fill").foregroundStyle(Theme.primary)
                Text("ShopDoctor").font(Theme.headline()).foregroundStyle(Theme.ink)
                Spacer()
                Text(L("Step %lld of %lld", step + 1, steps.count)).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                LanguageToggle()
            }
            Text(L(steps[step])).font(Theme.title()).foregroundStyle(Theme.ink)
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.primary : Theme.hairline).frame(height: 4)
                }
            }
        }
        .padding(Theme.gutter)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button(L("Back")) { withAnimation { step -= 1 } }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 110)
            }
            Button {
                if step < steps.count - 1 {
                    withAnimation { step += 1 }
                } else {
                    Task { await state.submit(draft.input, uploads: draft.uploads) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(step == steps.count - 1 ? L("Run diagnosis") : L("Continue"))
                        .contentTransition(.interpolate)
                    Image(systemName: step == steps.count - 1 ? "stethoscope" : "arrow.right")
                        .contentTransition(.symbolEffect(.replace))
                }
                .animation(.snappy(duration: 0.25), value: step)
            }
            .buttonStyle(PrimaryButtonStyle(enabled: canContinue))
            .disabled(!canContinue)
        }
        .padding(Theme.gutter)
        .background(Theme.background.shadow(.drop(color: Theme.ink.opacity(0.06), radius: 8, y: -2)))
    }

    private var canContinue: Bool {
        switch step {
        case 0: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && !draft.category.isEmpty
        case 3: draft.coordinate != nil
        default: true
        }
    }
}

// MARK: - Draft model

struct IntakeDraft {
    var name = ""
    var category = ""
    var district = "Mong Kok"
    var openedYear = Calendar.current.component(.year, from: .now) - 3
    var weeklyHours: Double = 70

    var menuPhotos: [Data] = []
    var shopfrontPhotos: [Data] = []
    var financialDocs: [(data: Data, mime: String)] = []

    var revenue: [String: Double] = [:]  // "YYYY-MM" -> HKD
    var costs = Costs()

    var address: String?
    var coordinate: CLLocationCoordinate2D?

    /// The last six complete months, oldest first.
    static var recentMonths: [String] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return (1...6).reversed().compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: .now) }.map(f.string)
    }

    var input: ShopInput {
        ShopInput(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            district: district,
            address: address,
            lat: coordinate?.latitude ?? CLLocationCoordinate2D.hongKong.latitude,
            lng: coordinate?.longitude ?? CLLocationCoordinate2D.hongKong.longitude,
            openedYear: openedYear,
            weeklyHours: weeklyHours,
            monthlyRevenue: Self.recentMonths.compactMap { m in revenue[m].flatMap { $0 > 0 ? MonthValue(month: m, amount: $0) : nil } },
            costs: costs
        )
    }

    var uploads: [Upload] {
        menuPhotos.enumerated().map { Upload(kind: .menu, data: $1, mimeType: "image/jpeg", filename: "menu-\($0).jpg") }
            + shopfrontPhotos.enumerated().map { Upload(kind: .shopfront, data: $1, mimeType: "image/jpeg", filename: "front-\($0).jpg") }
            + financialDocs.enumerated().map {
                Upload(kind: .financials, data: $1.data, mimeType: $1.mime, filename: "records-\($0).\($1.mime == "application/pdf" ? "pdf" : "jpg")")
            }
    }
}

// MARK: - Step 1: basics

private let categories = ["Cha chaan teng", "Noodle shop", "Café", "Bakery", "Bubble tea", "Dessert shop",
                          "Restaurant", "Hair salon", "Nail salon", "Convenience store", "Boutique", "Pharmacy"]

private let districts = ["Central", "Sheung Wan", "Wan Chai", "Causeway Bay", "North Point", "Quarry Bay",
                         "Aberdeen", "Tsim Sha Tsui", "Jordan", "Yau Ma Tei", "Mong Kok", "Prince Edward",
                         "Sham Shui Po", "Kowloon City", "To Kwa Wan", "Kwun Tong", "Wong Tai Sin", "Tsuen Wan",
                         "Kwai Chung", "Sha Tin", "Tai Po", "Tuen Mun", "Yuen Long", "Tseung Kwan O", "Tung Chung"]

private struct BasicsStep: View {
    @Binding var draft: IntakeDraft

    var body: some View {
        Text(L("Tell us the basics. We'll use them to find shops like yours nearby."))
            .font(Theme.body).foregroundStyle(Theme.inkSecondary)

        FieldLabel(L("Shop name"))
        TextField(L("e.g. Wing Kee Café"), text: $draft.name)
            .textFieldStyle(SoftFieldStyle())

        FieldLabel(L("What kind of shop?"))
        FlowLayout(spacing: 8) {
            ForEach(categories, id: \.self) { c in
                Chip(text: L(c), selected: draft.category == c) { draft.category = c }
            }
        }

        FieldLabel(L("District"))
        Picker(L("District"), selection: $draft.district) {
            ForEach(districts, id: \.self) { Text(L($0)) }
        }
        .pickerStyle(.menu)
        .tint(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))

        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                FieldLabel(L("Opened in"))
                Stepper(value: $draft.openedYear, in: 1950...Calendar.current.component(.year, from: .now)) {
                    Text(String(draft.openedYear)).font(Theme.number(17))
                }
            }
        }

        FieldLabel(L("Open hours per week: %lld", Int(draft.weeklyHours)))
        Slider(value: $draft.weeklyHours, in: 20...168, step: 1)
    }
}

// MARK: - Step 2: photos

private struct PhotosStep: View {
    @Binding var draft: IntakeDraft
    @State private var importingPDF = false
    @State private var docSelection: [PhotosPickerItem] = []

    var body: some View {
        Text(L("Photos help the Doctor read your menu prices and see your shop the way a passer-by does. All optional."))
            .font(Theme.body).foregroundStyle(Theme.inkSecondary)

        PhotoSlot(title: L("Menu"), subtitle: L("Every page, straight on"), icon: "menucard", max: 6, photos: $draft.menuPhotos)
        PhotoSlot(title: L("Shopfront"), subtitle: L("From across the street, in daylight"), icon: "storefront", max: 3,
                  photos: $draft.shopfrontPhotos)

        Card {
            SectionTitle(title: L("Revenue & cost records"), subtitle: L("A P&L, ledger page or POS report. Photo or PDF."),
                         icon: "doc.text")
            if !draft.financialDocs.isEmpty {
                Pill(text: L("%lld attached", draft.financialDocs.count), icon: "checkmark")
            }
            HStack {
                PhotosPicker(selection: $docSelection, maxSelectionCount: 4, matching: .images) {
                    Label(L("Photos"), systemImage: "photo")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button { importingPDF = true } label: { Label("PDF", systemImage: "doc") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .onChange(of: docSelection) { _, items in
            guard !items.isEmpty else { return }
            load(items)
            docSelection = []
        }
        .fileImporter(isPresented: $importingPDF, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            for url in (try? result.get()) ?? [] {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) { draft.financialDocs.append((data, "application/pdf")) }
            }
        }
    }

    private func load(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let raw = try? await item.loadTransferable(type: Data.self), let jpeg = ImageEncoding.jpeg(from: raw) {
                    draft.financialDocs.append((jpeg, "image/jpeg"))
                }
            }
        }
    }
}

private struct PhotoSlot: View {
    let title: String
    let subtitle: String
    let icon: String
    let max: Int
    @Binding var photos: [Data]
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        Card {
            HStack {
                SectionTitle(title: title, subtitle: subtitle, icon: icon)
                Spacer()
                if !photos.isEmpty { Pill(text: "\(photos.count)", icon: "checkmark") }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PhotosPicker(selection: $selection, maxSelectionCount: max, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title3)
                            Text(L("Add")).font(Theme.caption)
                        }
                        .foregroundStyle(Theme.primaryDark)
                        .frame(width: 76, height: 76)
                        .background(Theme.primarySoft, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    ForEach(photos.indices, id: \.self) { i in
                        Thumbnail(data: photos[i])
                    }
                }
            }
        }
        .onChange(of: selection) { _, items in
            Task {
                var loaded: [Data] = []
                for item in items {
                    if let raw = try? await item.loadTransferable(type: Data.self), let jpeg = ImageEncoding.jpeg(from: raw) {
                        loaded.append(jpeg)
                    }
                }
                photos = loaded
            }
        }
    }
}

private struct Thumbnail: View {
    let data: Data
    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            }
            #else
            if let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            }
            #endif
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }
}

// MARK: - Step 3: money

private struct MoneyStep: View {
    @Binding var draft: IntakeDraft

    var body: some View {
        Text(L("Rough numbers are fine. If you attached records, leave these blank and we'll read them."))
            .font(Theme.body).foregroundStyle(Theme.inkSecondary)

        Card {
            SectionTitle(title: L("Monthly revenue"), subtitle: L("Takings for each month, HKD"), icon: "chart.bar")
            ForEach(IntakeDraft.recentMonths, id: \.self) { month in
                MoneyRow(label: monthLabel(month), value: Binding(
                    get: { draft.revenue[month] ?? 0 },
                    set: { draft.revenue[month] = $0 }
                ))
            }
        }

        Card {
            SectionTitle(title: L("Monthly costs"), subtitle: L("A typical month, HKD"), icon: "creditcard")
            MoneyRow(label: L("Rent"), value: $draft.costs.rent)
            MoneyRow(label: L("Staff wages & MPF"), value: $draft.costs.staff)
            MoneyRow(label: L("Ingredients & stock"), value: $draft.costs.ingredients)
            MoneyRow(label: L("Utilities"), value: $draft.costs.utilities)
            MoneyRow(label: L("Other"), value: $draft.costs.other)
        }
    }

    private func monthLabel(_ month: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: month) else { return month }
        return date.formatted(.dateTime.month(.wide).year().locale(Localization.current.locale))
    }
}

private struct MoneyRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label).font(Theme.body).foregroundStyle(Theme.ink)
            Spacer()
            Text("HK$").font(Theme.caption).foregroundStyle(Theme.inkMuted)
            TextField("0", value: $value, format: .number.precision(.fractionLength(0)))
                .numericKeyboard()
                .multilineTextAlignment(.trailing)
                .font(Theme.number(16))
                .frame(width: 110)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Step 4: location

private struct LocationStep: View {
    @Binding var draft: IntakeDraft
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: .hongKong, latitudinalMeters: 2500, longitudinalMeters: 2500))
    @State private var locator = LocationService()

    var body: some View {
        Text(L("Drop the pin on your door. Twins are searched within about 1.5 km."))
            .font(Theme.body).foregroundStyle(Theme.inkSecondary)

        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkMuted)
            TextField(L("Search address or building"), text: $query)
                .onSubmit { Task { results = await LocationService.search(query) } }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))

        ForEach(results.prefix(4), id: \.self) { item in
            Button {
                select(item.placemark.coordinate, address: item.placemark.title)
                results = []
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? L("Result")).font(Theme.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(item.placemark.title ?? "").font(Theme.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }

        MapReader { proxy in
            Map(position: $camera) {
                if let c = draft.coordinate {
                    Annotation(L("Your shop"), coordinate: c) {
                        Image(systemName: "cross.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, Theme.primary)
                    }
                    MapCircle(center: c, radius: 1500)
                        .foregroundStyle(Theme.primary.opacity(0.06))
                        .stroke(Theme.primary.opacity(0.4), lineWidth: 1)
                }
            }
            .onTapGesture { point in
                if let c = proxy.convert(point, from: .local) { select(c, address: nil, move: false) }
            }
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

        Button {
            Task { if let c = await locator.current() { select(c, address: nil) } }
        } label: {
            Label(L("Use my current location"), systemImage: "location.fill")
        }
        .buttonStyle(SecondaryButtonStyle())

        if let address = draft.address {
            Label(address, systemImage: "mappin").font(Theme.caption).foregroundStyle(Theme.inkSecondary)
        }
    }

    private func select(_ c: CLLocationCoordinate2D, address: String?, move: Bool = true) {
        draft.coordinate = c
        if let address { draft.address = address }
        if move {
            withAnimation { camera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 2500, longitudinalMeters: 2500)) }
        }
    }
}

// MARK: - Small form pieces

private struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary).padding(.top, 4)
    }
}

struct SoftFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall).stroke(Theme.hairline))
    }
}

struct Chip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Theme.body.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Theme.primary : Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Theme.hairline))
        }
        .buttonStyle(.plain)
    }
}

/// Wraps children onto new lines like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + size.width > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

/// Compact EN | 中 switch for the intake header.
private struct LanguageToggle: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguage.allCases) { lang in
                Button { state.language = lang } label: {
                    Text(lang.shortName)
                        .font(Theme.caption.weight(.semibold))
                        .foregroundStyle(state.language == lang ? .white : Theme.inkSecondary)
                        .frame(width: 32, height: 24)
                        .background(state.language == lang ? Theme.primary : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lang.nativeName)
            }
        }
        .padding(2)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline))
    }
}
