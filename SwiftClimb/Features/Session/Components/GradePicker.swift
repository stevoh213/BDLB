import SwiftUI

/// Native iOS picker wheel for grade selection
struct GradePicker: View {
    let discipline: Discipline
    @Binding var selectedGrade: String
    @Binding var selectedScale: GradeScale

    private var availableGrades: [String] {
        Grade.grades(for: selectedScale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            // Scale selector (only for routes with multiple scales)
            if discipline != .bouldering {
                HStack {
                    Text("Scale")
                        .font(SCTypography.body.weight(.medium))

                    Spacer()

                    Picker("Scale", selection: $selectedScale) {
                        ForEach(discipline.availableGradeScales, id: \.self) { scale in
                            Text(scale.displayName).tag(scale)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Grade picker wheel
            Picker("Grade", selection: $selectedGrade) {
                ForEach(availableGrades, id: \.self) { grade in
                    Text(grade).tag(grade)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
        .onChange(of: selectedScale) { _, newScale in
            // Reset to middle-ish grade when scale changes
            let grades = Grade.grades(for: newScale)
            let midIndex = grades.count / 2
            selectedGrade = grades[midIndex]
        }
    }
}

#Preview("Boulder") {
    @Previewable @State var grade = "V5"
    @Previewable @State var scale: GradeScale = .v

    GradePicker(
        discipline: .bouldering,
        selectedGrade: $grade,
        selectedScale: $scale
    )
    .padding()
}

#Preview("Sport") {
    @Previewable @State var grade = "5.11a"
    @Previewable @State var scale: GradeScale = .yds

    GradePicker(
        discipline: .sport,
        selectedGrade: $grade,
        selectedScale: $scale
    )
    .padding()
}
