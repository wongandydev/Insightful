import SwiftUI

/// Conversational goal-setup screen. Owns a ``GoalSetupViewModel`` and
/// renders the transcript plus a single text-entry composer at the bottom.
struct GoalSetupView: View {
    @State private var viewModel: GoalSetupViewModel
    @FocusState private var inputFocused: Bool

    init(goalService: any GoalServicing, onComplete: @escaping () -> Void) {
        _viewModel = State(initialValue: GoalSetupViewModel(
            goalService: goalService,
            onComplete: onComplete
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            transcript
            errorBanner
            composer
        }
        .task { await viewModel.start() }
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
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
            }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
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
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($inputFocused)
                .disabled(viewModel.isSending)
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
