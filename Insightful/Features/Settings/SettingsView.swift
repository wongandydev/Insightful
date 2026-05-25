import SwiftUI

/// Bare-bones settings sheet. Two actions: re-do goal setup, or sign out
/// (which the parent uses to trigger a full cold-start with a fresh
/// anonymous user).
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var showSignOutConfirmation = false
    @State private var showResetGoalConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(
        authService: AuthService,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: SettingsViewModel(
            authService: authService,
            onSignedOut: onSignedOut,
            onResetGoal: onResetGoal
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Goal") {
                    Button("Re-do goal setup") {
                        showResetGoalConfirmation = true
                    }
                    .disabled(viewModel.isSigningOut)
                }
                Section("Account") {
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
            .confirmationDialog(
                "Re-do goal setup?",
                isPresented: $showResetGoalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Re-do goal setup", role: .destructive) {
                    viewModel.resetGoal()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll go through the goal-setup conversation again. Your current goal stays saved in the meantime.")
            }
        }
    }
}
