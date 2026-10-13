import SwiftUI

/// Summary first: score and key measurements, the 3D model with pins, then the fix list.
struct ExperienceResultView: View {
    @Environment(AppState.self) private var state
    let audit: ExperienceAudit
    let onRecheck: () -> Void

    @State private var done: Set<String> = []
    @State private var fixPlanStart: Int?

    private var progress: Double { audit.issues.isEmpty ? 1 : Double(done.count) / Double(audit.issues.count) }
    private var firstOpen: Int { audit.issues.firstIndex { !done.contains($0.id) } ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    HStack(spacing: 18) {
                        ScoreRing(score: audit.overall, size: 104, lineWidth: 10)
                        Text(audit.verdict).font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    if let m = audit.layout {
                        HStack(spacing: 10) {
                            StatTile(label: L("Seats"), value: "\(m.seats)", detail: L("%lld tables", m.tables))
                            StatTile(label: L("Space per seat"), value: m.m2PerSeat.map { String(format: "%.1f m²", $0) } ?? "–")
                            StatTile(label: L("Narrowest aisle"), value: m.narrowestAisleM.map { String(format: "%.2f m", $0) } ?? "–",
                                     detail: (m.narrowestAisleM ?? 1) < 0.9 ? L("Below 0.9 m") : L("Comfortable"),
                                     detailTint: (m.narrowestAisleM ?? 1) < 0.9 ? Theme.critical : Theme.primaryDark)
                        }
                    }
                }

                if let room = audit.room {
                    Card(padding: 0) {
                        ShopModelView(room: room, issues: audit.issues, done: done) { id in
                            fixPlanStart = audit.issues.firstIndex { $0.id == id }
                        }
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text(L("Drag to turn · pinch to zoom · tap a pin"))
                                .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.white.opacity(0.85), in: Capsule())
                                .padding(12)
                        }
                    }
                }

                Card {
                    HStack {
                        SectionTitle(title: L("Your fix plan"), subtitle: L("%lld of %lld fixed", done.count, audit.issues.count), icon: "checklist")
                        Spacer()
                    }
                    ProgressView(value: progress).tint(Theme.primary)
                    Button { fixPlanStart = firstOpen } label: {
                        HStack(spacing: 8) {
                            Text(done.isEmpty ? L("Start fixing") : L("Continue fixing"))
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: !audit.issues.isEmpty))
                    ForEach(Array(audit.issues.enumerated()), id: \.element.id) { i, issue in
                        Button { fixPlanStart = i } label: {
                            IssueRow(number: i + 1, issue: issue, done: done.contains(issue.id))
                        }
                        .buttonStyle(.plain)
                        if i < audit.issues.count - 1 { Divider().overlay(Theme.hairline) }
                    }
                }

                Card {
                    SectionTitle(title: L("How the shop scores"), subtitle: L("Out of 10, from a customer's point of view"), icon: "person.crop.circle.badge.checkmark")
                    ForEach(audit.areas.sorted { $0.score < $1.score }) { a in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(a.label).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                                Spacer()
                                Text("\(Int(a.score.rounded()))/10").font(Theme.number(13)).foregroundStyle(Theme.ink)
                            }
                            ScoreBar(score: a.score * 10)
                        }
                    }
                }

                if !audit.notes.isEmpty {
                    Card {
                        SectionTitle(title: L("About this check"), icon: "info.circle")
                        ForEach(audit.notes, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
                    }
                }

                HStack(spacing: 10) {
                    Button { state.selectedTab = .doctor } label: { Label(L("Ask the Doctor"), systemImage: "stethoscope") }
                        .buttonStyle(SecondaryButtonStyle())
                    Button { onRecheck() } label: { Label(L("Check again"), systemImage: "arrow.clockwise") }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(Theme.gutter)
        }
        .background(Theme.surface.opacity(0.5))
        .onAppear {
            done = ExperienceStore.done(for: audit)
            #if DEBUG
            if UserDefaults.standard.string(forKey: "debugScreen") == "fixplan" { fixPlanStart = 0 }
            #endif
        }
        .fullScreenCover(item: Binding(get: { fixPlanStart.map(FixPlanStart.init) }, set: { fixPlanStart = $0?.index })) { start in
            FixPlanView(audit: audit, startIndex: start.index, done: $done, onRecheck: {
                fixPlanStart = nil
                onRecheck()
            })
        }
        .onChange(of: done) { _, new in ExperienceStore.setDone(new, for: audit) }
    }
}

private struct FixPlanStart: Identifiable {
    let index: Int
    var id: Int { index }
}

struct IssueRow: View {
    let number: Int
    let issue: ExperienceIssue
    let done: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(done ? Theme.primary : (issue.impact == .high ? Theme.critical : Theme.warning))
                if done {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(Theme.number(13)).foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title).font(Theme.headline(15)).foregroundStyle(done ? Theme.inkMuted : Theme.ink)
                    .strikethrough(done, color: Theme.inkMuted)
                IssueChips(issue: issue)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.inkMuted).padding(.top, 6)
        }
        .contentShape(Rectangle())
    }
}

struct IssueChips: View {
    let issue: ExperienceIssue

    var body: some View {
        HStack(spacing: 6) {
            Pill(text: sentenceCase(L("%@ impact", L(issue.impact.rawValue))), tint: issue.impact == .high ? Theme.critical : Theme.inkSecondary)
            Pill(text: sentenceCase(L("%@ cost", L(issue.cost.rawValue))), tint: Theme.inkSecondary)
            Pill(text: issue.effort, icon: "clock", tint: Theme.inkSecondary)
        }
    }
}
