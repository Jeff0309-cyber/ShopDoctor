import SwiftUI

/// The first thing an owner sees after the Doctor finishes thinking: the prescription
/// printing out, full screen. The way forward appears once it has been signed.
struct PrescriptionRevealView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("printedDiagnosis") private var printedDiagnosis = ""
    @State private var showActions = false

    /// Slip timing: 0.4s pause + 1.75s feed + 1.8s signature.
    private let printAndSignSeconds = 4.1

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L("Diagnosis complete"), systemImage: "checkmark.seal.fill")
                            .font(Theme.caption.weight(.semibold))
                            .foregroundStyle(Theme.primaryDark)
                        Text(L("Your prescription")).font(Theme.title()).foregroundStyle(Theme.ink)
                    }
                    if let shop = state.shop, let d = state.diagnosis {
                        PrescriptionSlip(shop: shop, diagnosis: d)
                    }
                }
                .padding(Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollEdgeFade(16)

            if showActions {
                VStack(spacing: 10) {
                    Button { state.openCheckup() } label: {
                        HStack(spacing: 8) {
                            Text(L("See my full check-up"))
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button { state.openCheckup(on: .doctor) } label: {
                        Label(L("Ask the Doctor about this"), systemImage: "stethoscope")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(Theme.gutter)
                .background(Theme.background.shadow(.drop(color: Theme.ink.opacity(0.06), radius: 8, y: -2)))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Theme.surface.opacity(0.5))
        .task {
            let alreadyPrinted = printedDiagnosis == state.diagnosis?.generatedAt
            if !(reduceMotion || alreadyPrinted) {
                try? await Task.sleep(for: .seconds(printAndSignSeconds))
            }
            withAnimation(.snappy(duration: 0.35)) { showActions = true }
        }
    }
}
