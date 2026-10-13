import SwiftUI

/// Shown while the backend reads photos, finds twins and scores the shop.
/// The cross traces itself while work is in flight and fills in when the result lands.
struct DiagnosingView: View {
    @Environment(AppState.self) private var state
    @State private var stage = 0
    @State private var thoughtThrough = false  // every stage has had its moment on screen
    private let stageSeconds = 1.8

    private let stages = [
        ("doc.text.magnifyingglass", "Reading your menu and records"),
        ("map", "Finding twin shops nearby"),
        ("building.2", "Sorting survivors from closures"),
        ("waveform.path.ecg", "Taking your shop's vital signs"),
        ("pills", "Writing your prescription"),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            // Resolve only when the result is in AND the thinking has played out,
            // so even an instant response gets a considered pause.
            CrossTraceLoader(complete: finished, size: 104) {
                state.finishDiagnosing()
            }

            VStack(spacing: 6) {
                Text(finished ? L("Diagnosis ready") : L("Examining your shop"))
                    .font(Theme.title(24)).foregroundStyle(Theme.ink)
                    .contentTransition(.interpolate)
                Text(finished ? L("Printing your prescription…") : L("The Doctor is thinking it through."))
                    .font(Theme.body).foregroundStyle(Theme.inkSecondary)
                    .contentTransition(.interpolate)
            }
            .animation(.snappy, value: finished)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(stages.indices, id: \.self) { i in
                    let done = i < stage || finished
                    let current = i == stage && !finished
                    HStack(spacing: 12) {
                        Group {
                            if done {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                            } else if current {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: stages[i].0).foregroundStyle(Theme.inkMuted)
                            }
                        }
                        .frame(width: 22)
                        Group {
                            if current {
                                ScrambleText(text: L(stages[i].1))
                            } else {
                                Text(L(stages[i].1))
                            }
                        }
                        .font(Theme.body.weight(current ? .semibold : .regular))
                        .foregroundStyle(done || current ? Theme.ink : Theme.inkMuted)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
            Spacer()
        }
        .padding(Theme.gutter)
        .task {
            // The backend does this in one request; the stages pace the wait
            // and hold at the last step until the result actually arrives.
            for i in 1..<stages.count {
                try? await Task.sleep(for: .seconds(stageSeconds))
                withAnimation { stage = i }
            }
            try? await Task.sleep(for: .seconds(stageSeconds))
            thoughtThrough = true
        }
    }

    private var finished: Bool { state.diagnosisReady && thoughtThrough }
}
