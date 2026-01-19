import SwiftUI

@MainActor
struct AuthView: View {
    @State private var authManager: SupabaseAuthManager
    @State private var isSignUp: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var handle: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    #if DEBUG
    private let onDevBypass: (() -> Void)?

    init(authManager: SupabaseAuthManager, onDevBypass: (() -> Void)? = nil) {
        self._authManager = State(initialValue: authManager)
        self.onDevBypass = onDevBypass
    }
    #else
    init(authManager: SupabaseAuthManager) {
        self._authManager = State(initialValue: authManager)
    }
    #endif

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    // Logo and title
                    VStack(spacing: SCSpacing.md) {
                        Text("SwiftClimb")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, SCSpacing.xxl)

                    // Auth form
                    SCGlassCard {
                        VStack(spacing: SCSpacing.lg) {
                            if isSignUp {
                                signUpForm
                            } else {
                                loginForm
                            }

                            Divider()

                            // Toggle between login and sign up
                            Button {
                                isSignUp.toggle()
                                clearForm()
                            } label: {
                                Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, SCSpacing.lg)

                    #if DEBUG
                    // Dev bypass section
                    if let onDevBypass = onDevBypass {
                        devBypassSection(onDevBypass: onDevBypass)
                    }
                    #endif
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: SCSpacing.md) {
            Text("Sign In")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: SCSpacing.sm) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
            }

            SCPrimaryButton(
                title: "Sign In",
                action: handleSignIn,
                isLoading: authManager.isLoading,
                isFullWidth: true
            )
        }
    }

    // MARK: - Sign Up Form

    private var signUpForm: some View {
        VStack(spacing: SCSpacing.md) {
            Text("Create Account")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: SCSpacing.sm) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $handle)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if !passwordsMatch && !confirmPassword.isEmpty {
                Text("Passwords do not match")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SCPrimaryButton(
                title: "Sign Up",
                action: handleSignUp,
                isLoading: authManager.isLoading,
                isFullWidth: true
            )
            .disabled(!isSignUpValid)
        }
    }

    // MARK: - Computed Properties

    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    private var isSignUpValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !handle.isEmpty &&
        passwordsMatch &&
        password.count >= 6
    }

    // MARK: - Actions

    private func handleSignIn() {
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func handleSignUp() {
        guard isSignUpValid else { return }

        Task {
            do {
                try await authManager.signUp(email: email, password: password, handle: handle)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        handle = ""
        errorMessage = ""
        showError = false
    }

    // MARK: - Dev Bypass (DEBUG only)

    #if DEBUG
    @ViewBuilder
    private func devBypassSection(onDevBypass: @escaping () -> Void) -> some View {
        VStack(spacing: SCSpacing.md) {
            Divider()
                .padding(.vertical, SCSpacing.md)

            Text("Developer Options")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Button {
                onDevBypass()
            } label: {
                HStack {
                    Image(systemName: "hammer.fill")
                    Text("Skip Login (Dev Bypass)")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(SCCornerRadius.button)
            }

            Text("Uses mock user ID for testing")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, SCSpacing.lg)
        .padding(.bottom, SCSpacing.xl)
    }
    #endif
}

#Preview {
    let client = SupabaseClientActor()
    let repository = SupabaseRepository(client: client)
    let profilesTable = ProfilesTable(repository: repository)
    let authManager = SupabaseAuthManager(client: client, profilesTable: profilesTable)
    AuthView(authManager: authManager)
}
