import SwiftUI

/// The diagnosis prints out of a slot as a signed prescription slip
/// (after the Kitchen's Receipt Printer + Animated Signature).
struct PrescriptionSlip: View {
    let shop: ShopProfile
    let diagnosis: Diagnosis

    /// Print once per diagnosis; later visits show the slip already printed.
    @AppStorage("printedDiagnosis") private var printedDiagnosis = ""
    @State private var fed: CGFloat = 0
    @State private var paperHeight: CGFloat = 0
    @State private var signed = false
    @State private var printing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    private let monoBold = Font.system(size: 13, weight: .bold, design: .monospaced)
    private let paper = Color(hex: 0xFCFBF7)

    var body: some View {
        VStack(spacing: 0) {
            slot
            paperSheet
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { paperHeight = g.size.height }
                        .onChange(of: g.size.height) { _, h in paperHeight = h }
                })
                // Feed: the sheet slides down out of the slot.
                .offset(y: -(1 - fed) * paperHeight)
                .frame(height: paperHeight == 0 ? nil : paperHeight * fed, alignment: .bottom)
                .clipped()
                .padding(.horizontal, 14)
        }
        .task(id: diagnosis.generatedAt) { await feed() }
        .sensoryFeedback(.success, trigger: signed) { _, new in new }
    }

    private var slot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Theme.ink.opacity(0.92), Theme.ink], startPoint: .top, endPoint: .bottom))
            HStack(spacing: 8) {
                Circle().fill(printing ? Theme.warning : Theme.primary).frame(width: 7, height: 7)
                    .shadow(color: (printing ? Theme.warning : Theme.primary).opacity(0.8), radius: 4)
                ScrambleText(text: printing ? L("PRINTING PRESCRIPTION") : L("PRESCRIPTION READY"))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "cross.case.fill").foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 16)
            // The paper exit slot
            Capsule().fill(.black).frame(height: 5).padding(.horizontal, 10)
                .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
        }
        .frame(height: 52)
        .zIndex(1)
    }

    private var paperSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("℞").font(.system(size: 30, weight: .bold, design: .serif)).foregroundStyle(Theme.primaryDark)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("SHOPDOCTOR CLINIC")).font(monoBold)
                    Text(shop.name.uppercased()).font(mono).lineLimit(1)
                }
                Spacer()
                Text(Date.now.formatted(.dateTime.day().month(.twoDigits).year(.twoDigits))).font(mono)
            }
            rule
            row(L("HEALTH SCORE"), "\(Int(diagnosis.health.overall.rounded()))/100")
            row(L("CONDITION"), diagnosis.health.band.label.uppercased())
            row(L("CLOSED NEARBY"), L("%lld OF %lld", diagnosis.comparison.closedCount, diagnosis.comparison.closedCount + diagnosis.comparison.survivorCount))
            rule
            if diagnosis.prescriptions.isEmpty {
                Text(L("NO URGENT TREATMENT NEEDED.")).font(monoBold)
            }
            ForEach(Array(diagnosis.prescriptions.enumerated()), id: \.element.id) { i, p in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(i + 1).").font(monoBold)
                        Text(p.title.uppercased()).font(monoBold)
                        Spacer(minLength: 6)
                        Text(p.impact == .high ? "●●●" : p.impact == .medium ? "●●○" : "●○○")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.primaryDark)
                            .accessibilityLabel(L("%@ impact", L(p.impact.rawValue)))
                    }
                    Text(p.detail).font(mono).foregroundStyle(Theme.ink.opacity(0.85))
                    Text(L("BASED ON: %@", p.evidence)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.inkSecondary)
                }
                .padding(.vertical, 2)
            }
            rule
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("RE-CHECK IN 30 DAYS")).font(.system(size: 11, design: .monospaced))
                    Text(L("ESTIMATES, NOT GUARANTEES")).font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(Theme.inkSecondary)
                Spacer()
                VStack(spacing: 0) {
                    SignatureView(draw: signed).frame(width: 120)
                    Rectangle().fill(Theme.ink.opacity(0.3)).frame(width: 120, height: 0.5)
                    Text(L("DR. SHOPDOCTOR")).font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .background(paper)
        .clipShape(ZigzagBottom())
        .shadow(color: Theme.ink.opacity(0.10), radius: 10, y: 6)
        .overlay(alignment: .top) {
            // Shadow cast by the slot onto the emerging paper
            LinearGradient(colors: [Theme.ink.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom).frame(height: 10)
        }
    }

    private var rule: some View {
        Text(String(repeating: "- ", count: 40)).font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.inkMuted).lineLimit(1).truncationMode(.tail)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(mono)
            Spacer()
            Text(v).font(monoBold)
        }
    }

    private func feed() async {
        if printedDiagnosis == diagnosis.generatedAt || reduceMotion {
            fed = 1
            signed = true
            return
        }
        printing = true
        fed = 0
        try? await Task.sleep(for: .seconds(0.4))
        // A thermal head advances line by line: 20 short steps with pauses between.
        for step in 1...20 {
            withAnimation(.linear(duration: 0.05)) { fed = CGFloat(step) / 20 }
            try? await Task.sleep(for: .seconds(0.0875))
            if Task.isCancelled { fed = 1; break }
        }
        printing = false
        signed = true
        printedDiagnosis = diagnosis.generatedAt
    }
}
