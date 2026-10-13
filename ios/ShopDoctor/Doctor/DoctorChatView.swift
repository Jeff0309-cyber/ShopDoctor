import SwiftUI

struct DoctorChatView: View {
    @Environment(AppState.self) private var state
    @State private var draft = ""
    @State private var streaming = false
    @State private var activity: String?
    @FocusState private var focused: Bool

    private var suggestions: [String] {
        ["Why is my score this low?", "What did the survivors do differently?", "What if I raise prices 10%?",
         "Should I open longer hours?", "How can I ease my rent pressure?"].map(L)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            intro
                            ForEach(state.chat) { m in
                                Bubble(message: m).id(m.id)
                            }
                            if let activity {
                                Label(activity, systemImage: "stethoscope")
                                    .font(Theme.caption).foregroundStyle(Theme.inkSecondary)
                                    .id("activity")
                            }
                            if state.chat.isEmpty { suggestionChips }
                        }
                        .padding(Theme.gutter)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollEdgeFade()
                    .onChange(of: state.chat.last?.content) { _, _ in
                        if let id = state.chat.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                composer
            }
            .background(Theme.background)
            .navigationTitle(L("Doctor"))
            .inlineNavigationTitle()
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.primary, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("ShopDoctor").font(Theme.headline(15)).foregroundStyle(Theme.ink)
                Text(L("I've read your check-up. Ask me about your score, your twins, or try a what-if."))
                    .font(Theme.body).foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.bottom, 8)
    }

    private var suggestionChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(suggestions, id: \.self) { s in
                Chip(text: s, selected: false) { send(s) }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField(L("Ask the Doctor…"), text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline))
                .onSubmit { send(draft) }
            Button { send(draft) } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? Theme.primary : Theme.inkMuted.opacity(0.5), in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel(L("Send"))
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 10)
        .background(Theme.background.shadow(.drop(color: Theme.ink.opacity(0.05), radius: 6, y: -2)))
    }

    private var canSend: Bool { !streaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !streaming, let shopID = state.shop?.id else { return }
        draft = ""
        state.chat.append(ChatMessage(role: .user, content: text))
        let history = state.chat
        state.chat.append(ChatMessage(role: .assistant, content: ""))
        let index = state.chat.count - 1
        streaming = true
        activity = L("Thinking…")

        Task {
            defer { streaming = false; activity = nil }
            do {
                for try await event in state.api.askDoctor(shopID: shopID, messages: history) {
                    switch event {
                    case .text(let t):
                        activity = nil
                        state.chat[index].content += t
                    case .tool(let name):
                        activity = Self.describe(tool: name)
                    case .error(let message):
                        state.chat[index].content += (state.chat[index].content.isEmpty ? "" : "\n\n") + message
                    case .done:
                        break
                    }
                }
            } catch {
                state.chat[index].content = L("I couldn't reach the server: %@", error.localizedDescription)
            }
            if state.chat[index].content.isEmpty { state.chat.remove(at: index) }
        }
    }

    private static func describe(tool: String) -> String {
        switch tool {
        case "get_diagnosis": L("Reviewing your check-up…")
        case "list_twins": L("Looking at your twin shops…")
        case "what_if": L("Running the numbers…")
        case "get_shop_experience": L("Looking at your shop check…")
        default: L("Working…")
        }
    }
}

private struct Bubble: View {
    let message: ChatMessage

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(markdown)
                .font(Theme.body)
                .foregroundStyle(isUser ? .white : Theme.ink)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Theme.primary : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !isUser { Spacer(minLength: 32) }
        }
    }

    private var markdown: AttributedString {
        (try? AttributedString(markdown: message.content,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(message.content)
    }
}
