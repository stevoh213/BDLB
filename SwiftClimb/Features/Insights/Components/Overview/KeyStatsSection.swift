// KeyStatsSection.swift
// SwiftClimb
//
// Displays max grades achieved by discipline.

import SwiftUI

/// A section showing maximum grades achieved by discipline.
///
/// Only shows disciplines where the user has sent at least one climb.
/// Respects the global time range filter.
@MainActor
struct KeyStatsSection: View {
    let stats: KeyStats

    private var hasAnyGrades: Bool {
        stats.maxBoulderGrade != nil ||
        stats.maxSportGrade != nil ||
        stats.maxTradGrade != nil ||
        stats.maxTopRopeGrade != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            InsightsSectionHeader(
                title: "Max Grades",
                subtitle: "Highest sends in period",
                systemImage: "arrow.up.circle.fill"
            )

            if hasAnyGrades {
                VStack(spacing: SCSpacing.xs) {
                    if let boulder = stats.maxBoulderGrade {
                        MaxGradeRow(discipline: .bouldering, grade: boulder)
                    }

                    if let sport = stats.maxSportGrade {
                        MaxGradeRow(discipline: .sport, grade: sport)
                    }

                    if let trad = stats.maxTradGrade {
                        MaxGradeRow(discipline: .trad, grade: trad)
                    }

                    if let topRope = stats.maxTopRopeGrade {
                        MaxGradeRow(discipline: .topRope, grade: topRope)
                    }
                }
                .padding(SCSpacing.md)
                .background(SCColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
            } else {
                EmptyMaxGradesView()
            }
        }
    }
}

// MARK: - Max Grade Row

@MainActor
private struct MaxGradeRow: View {
    let discipline: Discipline
    let grade: String

    private var disciplineColor: Color {
        switch discipline {
        case .bouldering: return .orange
        case .sport: return .blue
        case .trad: return .green
        case .topRope: return .purple
        }
    }

    private var disciplineIcon: String {
        switch discipline {
        case .bouldering: return "circle.hexagonpath"
        case .sport: return "bolt.fill"
        case .trad: return "wrench.and.screwdriver"
        case .topRope: return "arrow.up.and.down"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: disciplineIcon)
                .font(.body)
                .foregroundStyle(disciplineColor)
                .frame(width: 24)

            Text(discipline.displayName)
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textPrimary)

            Spacer()

            Text(grade)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(disciplineColor)
        }
        .padding(.vertical, SCSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(discipline.displayName): \(grade)")
    }
}

// MARK: - Empty State

@MainActor
private struct EmptyMaxGradesView: View {
    var body: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(SCColors.textTertiary)

            Text("No sends yet")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)

            Text("Complete some climbs to see your max grades")
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(SCSpacing.lg)
        .background(SCColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: SCCornerRadius.card))
    }
}

// MARK: - Preview

#Preview("With Grades") {
    ScrollView {
        KeyStatsSection(
            stats: KeyStats(
                totalClimbs: 100,
                totalSessions: 20,
                totalAttempts: 200,
                sendCount: 120,
                uniquePartners: 5,
                maxBoulderGrade: "V7",
                maxSportGrade: "5.12a",
                maxTradGrade: "5.10c",
                maxTopRopeGrade: nil
            )
        )
        .padding()
    }
    .background(Color(.systemBackground))
}

#Preview("Empty") {
    ScrollView {
        KeyStatsSection(stats: .empty)
            .padding()
    }
    .background(Color(.systemBackground))
}
