import SwiftUI
import SwiftData

@MainActor
struct EditProfileView: View {
    // MARK: - Bindable Profile
    @Bindable var profile: SCProfile

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.updateProfileUseCase) private var updateProfileUseCase
    @Environment(\.currentUserId) private var currentUserId

    // MARK: - Form State (copy for editing)
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var homeGym: String = ""
    @State private var handle: String = ""
    @State private var climbingSince: Date = Date()
    @State private var hasClimbingSince: Bool = false
    @State private var favoriteStyle: String = ""
    @State private var isPublic: Bool = false
    @State private var preferredGradeScaleBoulder: GradeScale = .v
    @State private var preferredGradeScaleRoute: GradeScale = .yds

    // MARK: - UI State
    @State private var isSaving = false
    @State private var errorMessage: String?

    // MARK: - Validation
    private var bioCharacterCount: Int { bio.count }
    private var bioIsValid: Bool { bioCharacterCount <= 280 }
    private var canSave: Bool { bioIsValid && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Identity Section
                Section("Identity") {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)

                    TextField("Handle", text: $handle)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                // MARK: - Bio Section
                Section {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)

                    HStack {
                        Spacer()
                        Text("\(bioCharacterCount)/280")
                            .font(SCTypography.metadata)
                            .foregroundStyle(bioIsValid ? SCColors.textSecondary : .red)
                    }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("Tell others about yourself and your climbing journey")
                }

                // MARK: - Climbing Info Section
                Section("Climbing Info") {
                    TextField("Home Gym", text: $homeGym)

                    // Favorite style picker
                    Picker("Favorite Style", selection: $favoriteStyle) {
                        Text("Not Set").tag("")
                        Text("Bouldering").tag("Bouldering")
                        Text("Sport").tag("Sport")
                        Text("Trad").tag("Trad")
                        Text("Top Rope").tag("Top Rope")
                    }

                    // Climbing since toggle + picker
                    Toggle("Show Climbing Since", isOn: $hasClimbingSince)

                    if hasClimbingSince {
                        DatePicker(
                            "Started Climbing",
                            selection: $climbingSince,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                // MARK: - Preferences Section
                Section("Preferences") {
                    Picker("Boulder Grade Scale", selection: $preferredGradeScaleBoulder) {
                        Text("V-Scale").tag(GradeScale.v)
                        Text("French").tag(GradeScale.french)
                    }

                    Picker("Route Grade Scale", selection: $preferredGradeScaleRoute) {
                        Text("YDS").tag(GradeScale.yds)
                        Text("French").tag(GradeScale.french)
                        Text("UIAA").tag(GradeScale.uiaa)
                    }
                }

                // MARK: - Privacy Section
                Section {
                    Toggle("Public Profile", isOn: $isPublic)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(isPublic
                        ? "Your profile can be discovered and viewed by other climbers"
                        : "Your profile is hidden from search and other climbers"
                    )
                }

                // MARK: - Error Display
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(SCTypography.secondary)
                    }
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
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadProfileData()
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // MARK: - Data Loading

    private func loadProfileData() {
        displayName = profile.displayName ?? ""
        bio = profile.bio ?? ""
        homeGym = profile.homeGym ?? ""
        handle = profile.handle
        favoriteStyle = profile.favoriteStyle ?? ""
        isPublic = profile.isPublic
        preferredGradeScaleBoulder = profile.preferredGradeScaleBoulder
        preferredGradeScaleRoute = profile.preferredGradeScaleRoute

        if let since = profile.climbingSince {
            climbingSince = since
            hasClimbingSince = true
        } else {
            hasClimbingSince = false
        }
    }

    // MARK: - Save Action

    private func saveProfile() async {
        guard let useCase = updateProfileUseCase else {
            errorMessage = "Profile service not available"
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await useCase.execute(
                profileId: profile.id,
                displayName: displayName.isEmpty ? nil : displayName,
                bio: bio.isEmpty ? nil : bio,
                homeGym: homeGym.isEmpty ? nil : homeGym,
                climbingSince: hasClimbingSince ? climbingSince : nil,
                favoriteStyle: favoriteStyle.isEmpty ? nil : favoriteStyle,
                isPublic: isPublic,
                handle: handle != profile.handle ? handle : nil
            )

            // Also update local preferences that aren't in the use case
            profile.preferredGradeScaleBoulder = preferredGradeScaleBoulder
            profile.preferredGradeScaleRoute = preferredGradeScaleRoute
            profile.updatedAt = Date()
            profile.needsSync = true

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
