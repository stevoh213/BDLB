import SwiftUI

/// Sheet for ending a session with RPE, pump level, and notes
struct EndSessionSheet: View {
    let session: SCSession
    let onEnd: (Int?, Int?, String?) -> Void
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rpe: Int = 5
    @State private var pumpLevel: Int = 3
    @State private var notes: String = ""

    private var sessionDuration: String {
        let elapsed = Date().timeIntervalSince(session.startedAt)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SCSpacing.lg) {
                    // Session Summary
                    SCGlassCard {
                        VStack(spacing: SCSpacing.sm) {
                            Text("Session Summary")
                                .font(SCTypography.cardTitle)

                            HStack(spacing: SCSpacing.lg) {
                                StatItem(value: sessionDuration, label: "Duration")
                                StatItem(value: "\(session.climbs.count)", label: "Climbs")
                                StatItem(value: "\(session.attemptCount)", label: "Attempts")
                            }
                        }
                    }

                    // RPE Picker
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Rate of Perceived Exertion")
                            .font(SCTypography.body.weight(.medium))

                        RPEPicker(value: $rpe)
                    }

                    // Pump Level
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Pump Level")
                            .font(SCTypography.body.weight(.medium))

                        PumpLevelPicker(value: $pumpLevel)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: SCSpacing.sm) {
                        Text("Session Notes")
                            .font(SCTypography.body.weight(.medium))

                        TextField("How did it go?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
            .navigationTitle("End Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onEnd(rpe, pumpLevel, notes.isEmpty ? nil : notes)
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
        }
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(SCTypography.sectionHeader)
            Text(label)
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textSecondary)
        }
    }
}

/// RPE picker with 1-10 scale
struct RPEPicker: View {
    @Binding var value: Int

    var body: some View {
        VStack(spacing: SCSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { rpe in
                    Button {
                        value = rpe
                    } label: {
                        Text("\(rpe)")
                            .font(SCTypography.body.weight(value == rpe ? .bold : .regular))
                            .frame(width: 32, height: 44)
                            .background(value == rpe ? Color.accentColor : SCColors.surfaceSecondary)
                            .foregroundStyle(value == rpe ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Easy")
                Spacer()
                Text("Hard")
            }
            .font(SCTypography.metadata)
            .foregroundStyle(SCColors.textSecondary)
        }
    }
}

/// Pump level picker with 1-5 scale
struct PumpLevelPicker: View {
    @Binding var value: Int

    private let labels = ["None", "Light", "Moderate", "Heavy", "Maxed"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { level in
                Button {
                    value = level
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: pumpIcon(for: level))
                            .font(.title2)
                        Text(labels[level - 1])
                            .font(SCTypography.metadata)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SCSpacing.sm)
                    .background(value == level ? Color.accentColor.opacity(0.2) : SCColors.surfaceSecondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(value == level ? Color.accentColor : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pumpIcon(for level: Int) -> String {
        switch level {
        case 1: return "drop"
        case 2: return "drop.fill"
        case 3: return "flame"
        case 4: return "flame.fill"
        case 5: return "bolt.fill"
        default: return "drop"
        }
    }
}

#Preview {
    EndSessionSheet(
        session: SCSession(userId: UUID(), discipline: .bouldering),
        onEnd: { _, _, _ in },
        isLoading: false
    )
}
