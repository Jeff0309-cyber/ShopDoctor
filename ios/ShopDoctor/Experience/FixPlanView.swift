import SwiftUI

/// Guided, one-fix-at-a-time walkthrough. The model (or the issue's photo) on top follows the
/// current fix; the card below says what we saw, why it matters and exactly what to do.
struct FixPlanView: View {
    @Environment(\.dismiss) private var dismiss
    let audit: ExperienceAudit
    @State var index: Int
    @Binding var done: Set<String>
    let onRecheck: () -> Void

    init(audit: ExperienceAudit, startIndex: Int, done: Binding<Set<String>>, onRecheck: @escaping () -> Void) {
        self.audit = audit
        _index = State(initialValue: startIndex)
        _done = done
        self.onRecheck = onRecheck
    }

    private var issue: ExperienceIssue { audit.issues[index] }
    private var allDone: Bool { audit.issues.allSatisfy { done.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            visual
                .frame(height: 250)
                .clipped()
            TabView(selection: $index) {
                ForEach(Array(audit.issues.enumerated()), id: \.element.id) { i, issue in
                    ScrollView { FixCard(number: i + 1, issue: issue, done: done.contains(issue.id), hasModel: audit.room != nil) }
                        .tag(i)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.snappy, value: index)
            footer
        }
        .background(Theme.background)
        .sensoryFeedback(.selection, trigger: index)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L("Fix %lld of %lld", index + 1, audit.issues.count)).font(Theme.headline()).foregroundStyle(Theme.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Theme.inkSecondary)
                        .frame(width: 36, height: 36).background(Theme.surface, in: Circle())
                }
                .accessibilityLabel(L("Close"))
            }
            // One segment per fix: green when done, ink for the current one.
            HStack(spacing: 4) {
                ForEach(Array(audit.issues.enumerated()), id: \.element.id) { i, item in
                    Capsule()
                        .fill(done.contains(item.id) ? Theme.primary : (i == index ? Theme.ink : Theme.hairline))
                        .frame(height: 4)
                }
            }
        }
        .padding(Theme.gutter)
    }

    @ViewBuilder private var visual: some View {
        if let room = audit.room, issue.roomTarget != nil {
            ShopModelView(room: room, issues: audit.issues, done: done, focused: issue.id) { id in
                if let i = audit.issues.firstIndex(where: { $0.id == id }) { index = i }
            }
        } else if let shot = issue.photoShot, let data = ExperienceStore.photo(shot), let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomLeading) {
                    Label(Shot(rawValue: shot)?.title ?? shot, systemImage: "camera")
                        .font(Theme.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(12)
                }
        } else if let room = audit.room {
            ShopModelView(room: room, issues: audit.issues, done: done, focused: nil)
        } else {
            ZStack {
                Theme.primarySoft
                Image(systemName: "storefront").font(.system(size: 54)).foregroundStyle(Theme.primary)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if allDone {
                VStack(spacing: 4) {
                    Label(L("All fixes done"), systemImage: "checkmark.seal.fill").font(Theme.headline()).foregroundStyle(Theme.primaryDark)
                    Text(L("Check again to see how your score changed.")).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                }
                Button { onRecheck() } label: {
                    HStack(spacing: 8) { Text(L("Check again")); Image(systemName: "arrow.clockwise") }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    toggleDone()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: done.contains(issue.id) ? "arrow.uturn.backward" : "checkmark")
                        Text(done.contains(issue.id) ? L("Mark as not done") : L("Mark as done"))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                HStack(spacing: 10) {
                    Button(L("Back")) { index = max(0, index - 1) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(index == 0)
                        .opacity(index == 0 ? 0.5 : 1)
                    Button(L("Next")) { index = min(audit.issues.count - 1, index + 1) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(index == audit.issues.count - 1)
                        .opacity(index == audit.issues.count - 1 ? 0.5 : 1)
                }
            }
        }
        .padding(Theme.gutter)
        .background(Theme.background.shadow(.drop(color: Theme.ink.opacity(0.06), radius: 8, y: -2)))
        .sensoryFeedback(.success, trigger: done.count) { old, new in new > old }
    }

    private func toggleDone() {
        if done.contains(issue.id) {
            done.remove(issue.id)
            return
        }
        done.insert(issue.id)
        // Move on to the next open fix after a beat, so the owner sees the tick land.
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            if let next = audit.issues.indices.first(where: { $0 > index && !done.contains(audit.issues[$0].id) })
                ?? audit.issues.indices.first(where: { !done.contains(audit.issues[$0].id) }) {
                index = next
            }
        }
    }
}

private struct FixCard: View {
    let number: Int
    let issue: ExperienceIssue
    let done: Bool
    let hasModel: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                if done {
                    Label(L("Done"), systemImage: "checkmark.circle.fill").font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primaryDark)
                }
                Text(issue.title).font(Theme.title(22)).foregroundStyle(Theme.ink)
                IssueChips(issue: issue)
            }
            section(L("What we noticed"), icon: "eye", text: issue.observation)
            section(L("Why it matters"), icon: "person.2", text: issue.whyItMatters)
            VStack(alignment: .leading, spacing: 10) {
                Label(L("How to fix it"), systemImage: "wrench.and.screwdriver").font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.primaryDark)
                ForEach(Array(issue.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(Theme.number(13)).foregroundStyle(.white)
                            .frame(width: 22, height: 22).background(Theme.primary, in: Circle())
                        Text(step).font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if issue.suggestedMove != nil && hasModel {
                    Label(L("The green shape on the model shows where it should go."), systemImage: "arrow.right.circle")
                        .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.primarySoft.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
        .padding(Theme.gutter)
    }

    private func section(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(Theme.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
            Text(text).font(Theme.body).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}
