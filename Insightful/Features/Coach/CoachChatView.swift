import SwiftUI

/// Free-form coaching conversation. Owns a ``CoachChatViewModel`` and
/// renders the transcript plus a single text-entry composer at the bottom —
/// the same chat shell as ``GoalSetupView`` without the completion overlay.
struct CoachChatView: View {
    @State private var viewModel: CoachChatViewModel
    @FocusState private var inputFocused: Bool

    init(
        adviceService: any AdviceServicing,
        healthKitService: any HealthKitServicing
    ) {
        _viewModel = State(initialValue: CoachChatViewModel(
            adviceService: adviceService,
            healthKitService: healthKitService
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            errorBanner
            composer
        }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        CoachMessageBubble(message: message)
                            .id(message.id)
                    }
                    if viewModel.isSending && viewModel.messages.last?.role != .assistant {
                        HStack {
                            ProgressView()
                            Text("Thinking…").foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { scrollToBottom(proxy) }
            .onChange(of: viewModel.isSending) { scrollToBottom(proxy) }
            .onChange(of: inputFocused) { _, focused in
                if focused { scrollToBottom(proxy) }
            }
        }
    }

    private let bottomAnchor = "bottom"

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask your coach", text: $viewModel.userInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($inputFocused)
                .disabled(viewModel.isSending)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onTapGesture { inputFocused = true }

            Button {
                inputFocused = false
                Task { await viewModel.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
            }
            .disabled(sendDisabled)
        }
        .padding(12)
        .background(.bar)
    }

    private var sendDisabled: Bool {
        viewModel.isSending ||
        viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        viewModel.threadId == nil
    }
}

/// One chat bubble. User turns hug the trailing edge; assistant turns hug
/// the leading edge.
private struct CoachMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(foreground)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var background: Color {
        switch message.role {
        case .user: return .accentColor
        case .assistant: return Color(.secondarySystemBackground)
        }
    }

    private var foreground: Color {
        switch message.role {
        case .user: return .white
        case .assistant: return .primary
        }
    }
}
