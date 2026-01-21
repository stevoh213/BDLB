import SwiftUI

/// Sheet for adding a new climb to the active session
struct AddClimbSheet: View {
    let session: SCSession
    let onAdd: (String, GradeScale, String?) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedGrade: String = "V5"
    @State private var selectedScale: GradeScale = .v
    @State private var climbName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GradePicker(
                        discipline: session.discipline,
                        selectedGrade: $selectedGrade,
                        selectedScale: $selectedScale
                    )
                } header: {
                    Text("Grade")
                } footer: {
                    Text("Required - select the grade of the climb")
                }

                Section {
                    TextField("e.g., Red corner problem", text: $climbName)
                } header: {
                    Text("Name (Optional)")
                } footer: {
                    Text("A name helps identify this climb later")
                }
            }
            .navigationTitle("Add Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task { await addClimb() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            // Set initial grade based on discipline
            let grades = Grade.grades(for: session.discipline.defaultGradeScale)
            selectedScale = session.discipline.defaultGradeScale
            selectedGrade = grades[grades.count / 2]  // Start in middle
        }
    }

    private func addClimb() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let name = climbName.isEmpty ? nil : climbName
            try await onAdd(selectedGrade, selectedScale, name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddClimbSheet(
        session: SCSession(userId: UUID(), discipline: .bouldering),
        onAdd: { _, _, _ in }
    )
}
