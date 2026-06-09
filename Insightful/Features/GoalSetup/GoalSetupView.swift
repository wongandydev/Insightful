import SwiftUI

/// Conversational goal-setup screen. Owns a ``GoalSetupViewModel`` and
/// renders the transcript plus a single text-entry composer at the bottom.
struct GoalSetupView: View {
    private let onCancel: (() -> Void)?
    @State private var viewModel: GoalSetupViewModel
    @FocusState private var inputFocused: Bool

    init(
        goalService: any GoalServicing,
        onComplete: @escaping (GoalContext) -> Void,
        onCancel: (() -> Void)?
    ) {
        self.onCancel = onCancel
        _viewModel = State(initialValue: GoalSetupViewModel(
            goalService: goalService,
            finalizingDelay: .milliseconds(800),
            onComplete: onComplete
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                resumedBanner
                transcript
                errorBanner
                composer
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: onCancel)
                            .disabled(viewModel.isFinalizing)
                    }
                }
            }
        }
        .task { await viewModel.start() }
        .overlay {
            if viewModel.isFinalizing {
                finalizingOverlay
            }
        }
    }

    private var finalizingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Finalizing your goal…")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
        .transition(.opacity)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
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
    private var resumedBanner: some View {
        if viewModel.wasResumed {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.left")
                Text("Picking up where you left off")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
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
            TextField("Type your reply", text: $viewModel.userInput, axis: .vertical)
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
private struct MessageBubble: View {
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
