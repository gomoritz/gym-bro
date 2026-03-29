//
//  WorkoutHistoryDetailView.swift
//  gym-bro
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.gym-bro", category: "WorkoutHistoryDetailView")

struct WorkoutHistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSessions: [WorkoutSession]
    @Query private var allSplits: [Split]

    let session: WorkoutSession

    @State private var showDeleteConfirmation = false
    @State private var showSplitPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                generalDataSection
                statsSection
                analysesSection
                timelineSection
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(session)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Split Picker Sheet

    private var splitPickerSheet: some View {
        NavigationStack {
            List {
                if allSplits.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)

                        Text("No Splits Available")
                            .font(.headline)

                        Text("Create a split first to assign it to this workout")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(allSplits) { split in
                        Button {
                            assignSplit(split)
                        } label: {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(split.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let exercises = split.exercises, !exercises.isEmpty {
                                    Text("\(exercises.count) exercise\(exercises.count > 1 ? "s" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                    }
                }
            }
            .navigationTitle("Assign Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showSplitPicker = false
                    }
                }
            }
        }
    }

    private func assignSplit(_ split: Split) {
        session.split = split
        session.splitName = split.name
        session.splitId = split.id

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save split assignment: \(error.localizedDescription)")
        }
        showSplitPicker = false
    }

    // MARK: - General Data Section

    private var generalDataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("General Information")
                .font(.system(.title2, design: .rounded, weight: .bold))

            VStack(spacing: Theme.Spacing.md) {
                InfoRow(icon: "calendar", label: "Date", value: dateFormatter.string(from: session.startTime))
                InfoRow(icon: "clock", label: "Time", value: timeFormatter.string(from: session.startTime))

                if let endTime = session.endTime {
                    InfoRow(icon: "timer", label: "Duration",
                           value: formatDuration(endTime.timeIntervalSince(session.startTime)))
                }

                if session.split == nil || session.splitId == nil || session.splitName == nil {
                    HStack {
                        Label {
                            Text("Split")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        Button {
                            showSplitPicker = true
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text("Assign Split")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                } else {
                    InfoRow(icon: "list.bullet.clipboard", label: "Split", value: session.displaySplitName)
                }

                if let location = session.displayLocationName, !location.isEmpty {
                    InfoRow(icon: "location.fill", label: "Location", value: location)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .sheet(isPresented: $showSplitPicker) {
            splitPickerSheet
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Statistics")
                .font(.system(.title2, design: .rounded, weight: .bold))

            VStack(spacing: Theme.Spacing.lg) {
                HStack(spacing: Theme.Spacing.lg) {
                    StatCard(
                        title: "Total Weight",
                        value: String(format: "%.0f kg", totalMovedWeight),
                        icon: "scalemass.fill",
                        color: .purple
                    )

                    StatCard(
                        title: "Total Sets",
                        value: "\(totalSets)",
                        icon: "list.number",
                        color: .orange
                    )
                }

                HStack(spacing: Theme.Spacing.lg) {
                    StatCard(
                        title: "Total Reps",
                        value: "\(totalReps)",
                        icon: "repeat",
                        color: .green
                    )

                    StatCard(
                        title: "Exercises",
                        value: "\(uniqueExerciseCount)",
                        icon: "dumbbell.fill",
                        color: .blue
                    )
                }

                if let avgIntensity = averageIntensity {
                    StatCard(
                        title: "Avg Intensity",
                        value: String(format: "%.1f kg/rep", avgIntensity),
                        icon: "bolt.fill",
                        color: .yellow,
                        fullWidth: true
                    )
                }
            }

            if !exerciseVolumeBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Volume per Exercise")
                        .font(.headline)
                        .padding(.top, Theme.Spacing.sm)

                    ForEach(exerciseVolumeBreakdown, id: \.exercise.id) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "%.0f kg", item.volume))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: item.volume, total: totalMovedWeight)
                                .tint(.purple)
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }

    // MARK: - Analyses Section

    private var analysesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Analysis")
                .font(.system(.title2, design: .rounded, weight: .bold))

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if !personalRecords.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Label {
                            Text("Personal Records")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }

                        ForEach(personalRecords, id: \.exercise.id) { pr in
                            HStack {
                                Text(pr.exercise.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1f kg x %d", pr.weight, pr.reps))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.leading, 28)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }

                if let comparison = previousWorkoutComparison {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Label {
                            Text("Comparison to Previous")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ComparisonRow(
                                label: "Total Weight",
                                current: totalMovedWeight,
                                previous: comparison.totalWeight,
                                unit: "kg"
                            )

                            ComparisonRow(
                                label: "Total Reps",
                                current: Double(totalReps),
                                previous: Double(comparison.totalReps),
                                unit: "reps"
                            )

                            ComparisonRow(
                                label: "Duration",
                                current: session.endTime?.timeIntervalSince(session.startTime) ?? 0,
                                previous: comparison.duration,
                                unit: "min",
                                isDuration: true
                            )
                        }
                        .padding(.leading, 28)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }

                performanceInsights
            }
        }
    }

    private var performanceInsights: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label {
                Text("Insights")
                    .font(.headline)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)

                        Text(insight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.leading, 28)
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Timeline")
                .font(.system(.title2, design: .rounded, weight: .bold))

            if let orderedExercises = getOrderedExercises() {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseTimelineView(exercise, number: index + 1)
                    }
                }
            }
        }
    }

    private func exerciseTimelineView(_ exercise: Exercise, number: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label {
                    Text("\(number). \(exercise.name)")
                        .font(.headline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Spacer()

                if let volume = exerciseVolume(for: exercise) {
                    Text(String(format: "%.0f kg", volume))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.purple)
                }
            }

            if let sets = getSetsForExercise(exercise) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, workoutSet in
                        setTimelineRow(workoutSet, setNumber: index + 1)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func setTimelineRow(_ workoutSet: WorkoutSet, setNumber: Int) -> some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let weight = workoutSet.weight, let reps = workoutSet.reps {
                Text(String(format: "%.1f kg x %d", weight, reps))
                    .font(.caption)
                    .fontWeight(.semibold)

                if let volume = workoutSet.weight, let reps = workoutSet.reps {
                    Text(String(format: "(%.0f kg)", volume * Double(reps)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let duration = workoutSet.duration {
                Text("\(duration) min")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            Text(timeFormatter.string(from: workoutSet.startTime))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed Analytics (delegated to services)

    private var stats: SessionAnalyticsService.SessionStats {
        SessionAnalyticsService.computeStats(for: session)
    }

    private var totalMovedWeight: Double { stats.totalMovedWeight }
    private var totalSets: Int { stats.totalSets }
    private var totalReps: Int { stats.totalReps }
    private var uniqueExerciseCount: Int { stats.uniqueExerciseCount }
    private var averageIntensity: Double? { stats.averageIntensity }

    private var exerciseVolumeBreakdown: [SessionAnalyticsService.ExerciseVolume] {
        SessionAnalyticsService.computeVolumeBreakdown(for: session)
    }

    private func exerciseVolume(for exercise: Exercise) -> Double? {
        SessionAnalyticsService.exerciseVolume(for: exercise, in: session)
    }

    private var personalRecords: [SessionAnalyticsService.PersonalRecord] {
        SessionAnalyticsService.detectPersonalRecords(session: session, allSessions: allSessions)
    }

    private var previousWorkoutComparison: SessionAnalyticsService.WorkoutComparison? {
        SessionAnalyticsService.previousWorkoutComparison(session: session, allSessions: allSessions)
    }

    private var insights: [String] {
        SessionAnalyticsService.generateInsights(
            session: session,
            stats: stats,
            records: personalRecords,
            comparison: previousWorkoutComparison
        )
    }

    private func getOrderedExercises() -> [Exercise]? {
        SessionAnalyticsService.getOrderedExercises(for: session)
    }

    private func getSetsForExercise(_ exercise: Exercise) -> [WorkoutSet]? {
        SessionAnalyticsService.getSetsForExercise(exercise, in: session)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        FormatService.formatDuration(duration)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
            }

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var fullWidth: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)

                Spacer()
            }

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

struct ComparisonRow: View {
    let label: String
    let current: Double
    let previous: Double
    let unit: String
    var isDuration: Bool = false

    private var difference: Double {
        current - previous
    }

    private var percentageChange: Double {
        guard previous != 0 else { return 0 }
        return (difference / previous) * 100
    }

    private var isImprovement: Bool {
        if isDuration {
            return difference < 0
        } else {
            return difference > 0
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            HStack(spacing: Theme.Spacing.xs) {
                if abs(percentageChange) >= 1 {
                    Image(systemName: isImprovement ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(isImprovement ? .green : .red)
                        .font(.caption)

                    Text(String(format: "%.0f%%", abs(percentageChange)))
                        .font(.caption)
                        .foregroundStyle(isImprovement ? .green : .red)
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.gray)
                        .font(.caption)

                    Text("Similar")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutHistoryDetailView(session: WorkoutSession(startTime: Date(), endTime: Date().addingTimeInterval(3600)))
            .modelContainer(for: [WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self, GymLocation.self, ExerciseLocationProfile.self])
    }
}
