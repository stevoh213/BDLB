import SwiftUI

// MARK: - Handle Availability State

/// Represents the availability status of a username during sign-up.
///
/// The username availability check follows this flow:
/// 1. User types username → immediate format validation
/// 2. If format is valid → debounced API call (500ms) to check availability
/// 3. Result displayed with visual indicator (spinner/checkmark/X/warning)
/// 4. Sign-up button only enabled when status is `.available`
///
/// This enum drives the UI state for real-time username availability feedback.
enum HandleAvailability: Equatable {
    /// Initial state - no check performed yet
    case unchecked

    /// Currently checking availability with API (debounced)
    case checking

    /// Username is available for registration
    case available

    /// Username is already taken by another user
    case taken

    /// Username format is invalid (contains validation error message)
    case invalid(String)
}

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

    // Handle availability checking
    @State private var handleAvailability: HandleAvailability = .unchecked
    @State private var handleCheckTask: Task<Void, Never>?

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

                // Username field with availability indicator
                VStack(alignment: .leading, spacing: SCSpacing.xs) {
                    HStack {
                        TextField("Username", text: $handle)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: handle) { _, newValue in
                                checkHandleAvailability(newValue)
                            }

                        // Availability indicator
                        handleAvailabilityIndicator
                    }

                    // Availability feedback message
                    handleAvailabilityMessage
                }

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

    // MARK: - Handle Availability UI

    @ViewBuilder
    private var handleAvailabilityIndicator: some View {
        switch handleAvailability {
        case .unchecked:
            EmptyView()
        case .checking:
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Checking username availability")
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Username is available")
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Username is already taken")
        case .invalid(let message):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Invalid username: \(message)")
        }
    }

    @ViewBuilder
    private var handleAvailabilityMessage: some View {
        switch handleAvailability {
        case .unchecked, .checking:
            EmptyView()
        case .available:
            Text("Username is available")
                .font(.caption)
                .foregroundStyle(.green)
        case .taken:
            Text("Username is already taken")
                .font(.caption)
                .foregroundStyle(.red)
        case .invalid(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Handle Validation & Availability Check

    /// Checks username availability with debouncing and format validation.
    ///
    /// This function is called on every keystroke via `.onChange(of: handle)`.
    /// It implements the following logic:
    ///
    /// 1. **Cancels previous check**: Prevents API spam when user is still typing
    /// 2. **Format validation first**: Checks format locally before making API call
    /// 3. **Debouncing**: Waits 500ms before making the API request
    /// 4. **Availability check**: Calls Supabase to check if handle exists
    /// 5. **State update**: Updates UI indicator based on result
    ///
    /// The debouncing approach reduces API calls from ~10 per username to just 1,
    /// improving performance and reducing backend load.
    ///
    /// - Parameter newHandle: The username to check
    private func checkHandleAvailability(_ newHandle: String) {
        // Cancel any existing check
        handleCheckTask?.cancel()

        // Reset state if handle is empty
        guard !newHandle.isEmpty else {
            handleAvailability = .unchecked
            return
        }

        // Validate format first (local, instant feedback)
        if let validationError = validateHandleFormat(newHandle) {
            handleAvailability = .invalid(validationError)
            return
        }

        // Debounce: wait before checking availability
        handleAvailability = .checking
        handleCheckTask = Task {
            // Wait 500ms before making API call (debounce)
            try? await Task.sleep(for: .milliseconds(500))

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }

            do {
                let isAvailable = try await authManager.checkHandleAvailable(handle: newHandle)

                // Verify handle hasn't changed during async call
                guard handle == newHandle, !Task.isCancelled else { return }

                handleAvailability = isAvailable ? .available : .taken
            } catch {
                // On error, reset to unchecked - will be caught on submit
                // Note: Reset BEFORE guard to prevent stuck "checking" state
                // if user continued typing during the failed request
                handleAvailability = .unchecked
                guard handle == newHandle, !Task.isCancelled else { return }
            }
        }
    }

    /// Validates username format against requirements.
    ///
    /// Username requirements:
    /// - 3-20 characters in length
    /// - Alphanumeric characters and underscores only
    /// - Must start with a letter
    ///
    /// - Parameter handle: The username to validate
    /// - Returns: `nil` if valid, or a descriptive error message if invalid
    private func validateHandleFormat(_ handle: String) -> String? {
        // Length check
        if handle.count < 3 {
            return "Username must be at least 3 characters"
        }
        if handle.count > 20 {
            return "Username must be 20 characters or less"
        }

        // Character validation: alphanumeric and underscores only
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if handle.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            return "Username can only contain letters, numbers, and underscores"
        }

        // Must start with a letter
        if let first = handle.first, !first.isLetter {
            return "Username must start with a letter"
        }

        return nil
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
        password.count >= 6 &&
        handleAvailability == .available
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
        handleAvailability = .unchecked
        handleCheckTask?.cancel()
        handleCheckTask = nil
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
