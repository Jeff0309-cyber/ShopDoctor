import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var state
    @State private var editing: ShopInput?
    @State private var pendingReset = false

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Form {
                if let shop = state.shop {
                    Section(L("Shop")) {
                        LabeledContent(L("Name"), value: shop.name)
                        LabeledContent(L("Type"), value: L(shop.category))
                        LabeledContent(L("District"), value: L(shop.district))
                        if let a = shop.address { LabeledContent(L("Address"), value: a) }
                        if let h = shop.weeklyHours { LabeledContent(L("Open hours"), value: L("%lld h/week", Int(h))) }
                    }
                    Section(L("Monthly costs")) {
                        LabeledContent(L("Rent"), value: Fmt.hkd(shop.costs.rent, compact: false))
                        LabeledContent(L("Staff"), value: Fmt.hkd(shop.costs.staff, compact: false))
                        LabeledContent(L("Ingredients & stock"), value: Fmt.hkd(shop.costs.ingredients, compact: false))
                        LabeledContent(L("Utilities"), value: Fmt.hkd(shop.costs.utilities, compact: false))
                        LabeledContent(L("Other"), value: Fmt.hkd(shop.costs.other, compact: false))
                        Button(L("Update numbers")) { editing = shop.input }
                    }
                    if let menu = shop.menu {
                        Section(L("What we read from your menu")) {
                            LabeledContent(L("Items"), value: "\(menu.itemCount)")
                            if let avg = menu.avgPrice { LabeledContent(L("Average price"), value: Fmt.hkd(avg, compact: false)) }
                            LabeledContent(L("Clarity"), value: "\(Int(menu.clarityScore))/10")
                            ForEach(menu.notes, id: \.self) { Text($0).font(Theme.caption) }
                        }
                    }
                    if let front = shop.shopfront {
                        Section(L("What we saw at your shopfront")) {
                            LabeledContent(L("Signage"), value: "\(Int(front.signageScore))/10")
                            LabeledContent(L("Visibility"), value: "\(Int(front.visibilityScore))/10")
                            LabeledContent(L("Condition"), value: "\(Int(front.conditionScore))/10")
                            LabeledContent(L("Walk-in appeal"), value: "\(Int(front.appealScore))/10")
                            ForEach(front.observations, id: \.self) { Text($0).font(Theme.caption) }
                        }
                    }
                }
                Section {
                    Picker(L("Language"), selection: $state.language) {
                        ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(L("Language"))
                } footer: {
                    Text(L("Generated text switches language the next time the check-up runs. Pull down on the Check-up tab to refresh now."))
                }
                Section {
                    Button(L("Re-run diagnosis")) { Task { await state.rediagnose() } }
                }
                Section {
                    HoldToConfirmButton(label: L("Hold to start a new shop")) {
                        withAnimation(.snappy) { pendingReset = true }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text(L("Clears this shop's check-up from this phone."))
                }
                Section(L("Server")) {
                    TextField(L("Backend URL"), text: $state.serverURL)
                        .autocorrectionDisabled()
                        .font(Theme.caption)
                }
            }
            .navigationTitle(L("My shop"))
            .sheet(item: $editing) { input in
                EditNumbersSheet(input: input) { updated in
                    editing = nil
                    Task { await state.updateShop(updated) }
                }
            }
            .overlay(alignment: .bottom) {
                if pendingReset {
                    UndoBar(message: L("Starting a new shop…"),
                            onUndo: { withAnimation(.snappy) { pendingReset = false } },
                            onCommit: {
                                pendingReset = false
                                state.reset()
                            })
                    .padding(Theme.gutter)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

extension ShopInput: Identifiable {
    public var id: String { name + district }
}

private struct EditNumbersSheet: View {
    @State var input: ShopInput
    let onSave: (ShopInput) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Monthly revenue")) {
                    ForEach($input.monthlyRevenue) { $m in
                        row(m.month, $m.amount)
                    }
                    Button(L("Add this month")) {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM"
                        let month = f.string(from: .now)
                        if !input.monthlyRevenue.contains(where: { $0.month == month }) {
                            input.monthlyRevenue.append(MonthValue(month: month, amount: 0))
                        }
                    }
                }
                Section(L("Monthly costs")) {
                    row(L("Rent"), $input.costs.rent)
                    row(L("Staff"), $input.costs.staff)
                    row(L("Ingredients & stock"), $input.costs.ingredients)
                    row(L("Utilities"), $input.costs.utilities)
                    row(L("Other"), $input.costs.other)
                }
            }
            .navigationTitle(L("Update numbers"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("Save & re-check")) { onSave(input) } }
            }
        }
    }

    private func row(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0)))
                .numericKeyboard()
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }
}
