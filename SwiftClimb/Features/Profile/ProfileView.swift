import SwiftUI
import SwiftData

@MainActor
struct ProfileView: View {
    // Query user profile
    @Query private var profiles: [SCProfile]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.profileUseCase) private var profileUseCase
    @Environment(\.authManager) private var authManager

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingEditSheet = false

    private var currentProfile: SCProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SCSpacing.lg) {
                    if let profile = currentProfile {
                        profileContentView(profile)
                    } else {
                        emptyProfileView
                    }

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(SCTypography.secondary)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    signOutButton
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let profile = currentProfile {
                EditProfileView(profile: profile)
            }
        }
    }

    @ViewBuilder
    private func profileContentView(_ profile: SCProfile) -> some View {
        VStack(spacing: SCSpacing.md) {
            // Profile photo placeholder
            if let photoURL = profile.photoURL {
                Text("Photo: \(photoURL)")
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            } else {
                Circle()
                    .fill(SCColors.surfaceSecondary)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(SCColors.textSecondary)
                    }
            }

            // Handle
            Text("@\(profile.handle)")
                .font(SCTypography.screenHeader)

            // Profile info
            VStack(alignment: .leading, spacing: SCSpacing.sm) {
                if let homeZIP = profile.homeZIP {
                    InfoRow(label: "Home ZIP", value: homeZIP)
                }

                InfoRow(
                    label: "Boulder Grade",
                    value: profile.preferredGradeScaleBoulder.rawValue
                )

                InfoRow(
                    label: "Route Grade",
                    value: profile.preferredGradeScaleRoute.rawValue
                )

                InfoRow(
                    label: "Profile Visibility",
                    value: profile.isPublic ? "Public" : "Private"
                )
            }
            .padding()
            .background(SCColors.surfaceSecondary)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var emptyProfileView: some View {
        VStack(spacing: SCSpacing.md) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundStyle(SCColors.textSecondary)

            Text("No Profile Found")
                .font(SCTypography.sectionHeader)

            Text("Create your profile to get started")
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var signOutButton: some View {
        Button(action: signOut) {
            Text("Sign Out")
                .font(SCTypography.body)
                .foregroundStyle(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(SCColors.surfaceSecondary)
                .cornerRadius(12)
        }
    }

    private func loadProfile() async {
        guard let profileUseCase = profileUseCase else {
            errorMessage = "Profile service not available"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let remoteProfile = try await profileUseCase.loadProfile()
            modelContext.insert(remoteProfile)
            try modelContext.save()
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func signOut() {
        guard let authManager = authManager else {
            errorMessage = "Auth service not available"
            return
        }

        Task {
            await authManager.signOut()
        }
    }
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(SCTypography.secondary)
                .foregroundStyle(SCColors.textSecondary)
            Spacer()
            Text(value)
                .font(SCTypography.body)
        }
    }
}

// MARK: - Edit Profile Sheet

@MainActor
private struct EditProfileView: View {
    @Bindable var profile: SCProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Handle", text: $profile.handle)
                    TextField("Home ZIP", text: Binding(
                        get: { profile.homeZIP ?? "" },
                        set: { profile.homeZIP = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Preferences") {
                    Picker("Boulder Grade Scale", selection: $profile.preferredGradeScaleBoulder) {
                        ForEach([GradeScale.v, .french], id: \.self) { scale in
                            Text(scale.rawValue).tag(scale)
                        }
                    }

                    Picker("Route Grade Scale", selection: $profile.preferredGradeScaleRoute) {
                        ForEach([GradeScale.yds, .french, .uiaa], id: \.self) { scale in
                            Text(scale.rawValue).tag(scale)
                        }
                    }

                    Toggle("Public Profile", isOn: $profile.isPublic)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
        }
    }

    private func saveProfile() {
        profile.updatedAt = Date()
        profile.needsSync = true

        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Handle error
        }
    }
}

#Preview {
    ProfileView()
}
