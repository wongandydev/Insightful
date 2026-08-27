import AuthenticationServices
import SwiftUI

/// Bare-bones settings sheet. Surfaces the saved goal (with a path to refine
/// it), the durable identities that can be attached to this user, and a
/// sign-out action that drops the parent onto the sign-in screen.
struct SettingsView: View {
    let goalContext: GoalContext?
    @State private var viewModel: SettingsViewModel
    @State private var showSignOutConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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
                    if !viewModel.appleLinked && viewModel.linkedEmail == nil {
                        Text("You're anonymous — connect an Apple ID so your goal and history survive a new phone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.appleLinked {
                        LabeledContent("Apple ID", value: "Connected")
                    } else {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.email]
                            request.nonce = viewModel.appleRequestNonce()
                        } onCompletion: { result in
                            Task { await viewModel.handleAppleAuthorization(result) }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 44)
                        .disabled(viewModel.isLinkingApple)
                    }
                    if let appleMessage = viewModel.appleMessage {
                        Text(appleMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let appleError = viewModel.appleErrorMessage {
                        Text(appleError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if let linkedEmail = viewModel.linkedEmail {
                        LabeledContent("Signed in as", value: linkedEmail)
                        if let linkMessage = viewModel.linkMessage {
                            Text(linkMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Add an email to sign in on platforms without Apple ID.")
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
            .task {
                await viewModel.loadLinkedEmail()
                viewModel.loadAppleIdentity()
                await viewModel.loadReminderPreference()
            }
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
                if viewModel.hasDurableIdentity {
                    Text("Sign back in with your Apple ID or email to pick your goal and history back up.")
                } else {
                    Text("This device isn't connected to an account, so your goal and history can't be recovered afterwards.")
                }
            }
        }
    }
}
