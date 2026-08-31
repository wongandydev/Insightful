import AuthenticationServices
import SwiftUI

/// Sign-in screen shown after sign-out.
///
/// Offers the two durable identities the app can attach — Apple and email +
/// password — so an account holder returns to their own goal and history, and
/// a way to carry on anonymously for someone who never linked one.
struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(authService: AuthService, onSignedIn: @escaping () -> Void) {
        _viewModel = State(initialValue: SignInViewModel(
            authService: authService,
            onSignedIn: onSignedIn
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email]
                    request.nonce = viewModel.appleRequestNonce()
                } onCompletion: { result in
                    Task { await viewModel.handleAppleAuthorization(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .disabled(viewModel.isWorking)
                emailForm
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Divider()
                Button("Continue without an account") {
                    viewModel.continueAnonymously()
                }
                .font(.subheadline)
                .disabled(viewModel.isWorking)
                Text("You'll start fresh — a goal and history saved on a previous device stay with the account they were saved under.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("Sign back in")
                .font(.title.bold())
            Text("Use the Apple ID or email connected to your account and your goal and history come with you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var emailForm: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $viewModel.emailInput)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $viewModel.passwordInput)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.signInWithEmail() }
            } label: {
                if viewModel.isWorking {
                    HStack {
                        ProgressView()
                        Text("Signing in…")
                    }
                    .frame(maxWidth: .infinity, minHeight: 28)
                } else {
                    Text("Sign in")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isWorking)
        }
    }
}
