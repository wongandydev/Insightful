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
        notificationService: any NotificationScheduling,
        goalContext: GoalContext?,
        onSignedOut: @escaping () -> Void,
        onResetGoal: @escaping () -> Void
    ) {
        self.goalContext = goalContext
        _viewModel = State(initialValue: SettingsViewModel(
            authService: authService,
            notificationService: notificationService,
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
                Section("Notifications") {
                    Toggle("Daily insight reminder", isOn: Binding(
                        get: { viewModel.reminderEnabled },
                        set: { enabled in Task { await viewModel.setReminderEnabled(enabled) } }
                    ))
                    if viewModel.reminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: Binding(
                                get: { viewModel.reminderTime },
                                set: { time in Task { await viewModel.setReminderTime(time) } }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                    if let deniedMessage = viewModel.notificationsDeniedMessage {
                        Text(deniedMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
            .task { await viewModel.loadReminderPreference() }
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
