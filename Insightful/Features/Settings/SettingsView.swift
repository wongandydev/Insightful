import SwiftUI

/// Bare-bones settings sheet. Surfaces the saved goal (with a path to refine
/// it) and a sign-out action that the parent uses to trigger a full
/// cold-start with a fresh anonymous user.
struct SettingsView: View {
    let goalContext: GoalContext?
    @State private var viewModel: SettingsViewModel
    @State private var showSignOutConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(
        authService: AuthService,
        goalContext: GoalContext?,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        self.goalContext = goalContext
        _viewModel = State(initialValue: SettingsViewModel(
            authService: authService,
            onSignedOut: onSignedOut,
            onResetGoal: onResetGoal
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                if let goalContext {
                    Section("Goal") {
                        NavigationLink {
                            GoalSummaryView(
                                context: goalContext,
                                onContinue: nil,
                                onEditGoal: { viewModel.resetGoal() }
                            )
                            .navigationTitle("Your goal")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("View / edit my goal")
                                Text(goalContext.goalSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .disabled(viewModel.isSigningOut)
                    }
                }
                Section("Account") {
                    if let linkedEmail = viewModel.linkedEmail {
                        LabeledContent("Signed in as", value: linkedEmail)
                        if let linkMessage = viewModel.linkMessage {
                            Text(linkMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("You're anonymous — create an account so your goal and history survive a new phone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("Email", text: $viewModel.linkEmailInput)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password (8+ characters)", text: $viewModel.linkPasswordInput)
                            .textContentType(.newPassword)
                        Button {
                            Task { await viewModel.linkAccount() }
                        } label: {
                            if viewModel.isLinking {
                                HStack {
                                    ProgressView()
                                    Text("Creating account…")
                                }
                            } else {
                                Text("Create account")
                            }
                        }
                        .disabled(viewModel.isLinking)
                        if let linkError = viewModel.linkErrorMessage {
                            Text(linkError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        if viewModel.isSigningOut {
                            HStack {
                                ProgressView()
                                Text("Signing out…")
                            }
                        } else {
                            Text("Sign out")
                        }
                    }
                    .disabled(viewModel.isSigningOut)
                }
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadLinkedEmail() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(viewModel.isSigningOut)
                }
            }
            .confirmationDialog(
                "Sign out?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be signed in as a fresh user the next time the app opens.")
            }
        }
    }
}
