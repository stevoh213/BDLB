import SwiftUI

/// Segmented picker for selecting climbing discipline
struct DisciplinePicker: View {
    @Binding var selection: Discipline

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text("Discipline")
                .font(SCTypography.body.weight(.medium))

            Picker("Discipline", selection: $selection) {
                ForEach(Discipline.allCases, id: \.self) { discipline in
                    Text(discipline.displayName).tag(discipline)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    @Previewable @State var discipline: Discipline = .bouldering

    DisciplinePicker(selection: $discipline)
        .padding()
}
