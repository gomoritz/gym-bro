//
//  WorkoutHistoryDetailView.swift
//  gym-bro
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

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
            VStack(alignment: .leading, spacing: 24) {
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
                    VStack(spacing: 12) {
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(split.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let exercises = split.exercises, !exercises.isEmpty {
                                    Text("\(exercises.count) exercise\(exercises.count > 1 ? "s" : "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
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

        try? modelContext.save()
        showSplitPicker = false
    }

    // MARK: - General Data Section

    private var generalDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Information")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                InfoRow(icon: "calendar", label: "Date", value: dateFormatter.string(from: session.startTime))
                InfoRow(icon: "clock", label: "Time", value: timeFormatter.string(from: session.startTime))

                if let endTime = session.endTime {
                    InfoRow(icon: "timer", label: "Duration",
                           value: formatDuration(endTime.timeIntervalSince(session.startTime)))
                }

                if session.split == nil || session.splitId == nil || session.splitName == nil {
                    // Orphaned session - show assign button
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
                            HStack(spacing: 4) {
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

                if let location = session.location, !location.isEmpty {
                    InfoRow(icon: "location.fill", label: "Location", value: location)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showSplitPicker) {
            splitPickerSheet
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                HStack(spacing: 16) {
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

                HStack(spacing: 16) {
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Volume per Exercise")
                        .font(.headline)
                        .padding(.top, 8)

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
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Analyses Section

    private var analysesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                if !personalRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
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
                                Text(String(format: "%.1f kg × %d", pr.weight, pr.reps))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.leading, 28)
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                }

                if let comparison = previousWorkoutComparison {
                    VStack(alignment: .leading, spacing: 8) {
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
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }

                performanceInsights
            }
        }
    }

    private var performanceInsights: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Insights")
                    .font(.headline)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
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
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.title2)
                .fontWeight(.bold)

            if let orderedExercises = getOrderedExercises() {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                        exerciseTimelineView(exercise, number: index + 1)
                    }
                }
            }
        }
    }

    private func exerciseTimelineView(_ exercise: Exercise, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func setTimelineRow(_ workoutSet: WorkoutSet, setNumber: Int) -> some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let weight = workoutSet.weight, let reps = workoutSet.reps {
                Text(String(format: "%.1f kg × %d", weight, reps))
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

    // MARK: - Helper Methods

    private var totalMovedWeight: Double {
        guard let sets = session.sets else { return 0 }
        return sets.reduce(0) { total, set in
            if let weight = set.weight, let reps = set.reps {
                return total + (weight * Double(reps))
            }
            return total
        }
    }

    private var totalSets: Int {
        session.sets?.count ?? 0
    }

    private var totalReps: Int {
        guard let sets = session.sets else { return 0 }
        return sets.reduce(0) { total, set in
            total + (set.reps ?? 0)
        }
    }

    private var uniqueExerciseCount: Int {
        guard let sets = session.sets else { return 0 }
        let uniqueExercises = Set(sets.compactMap { $0.exercise?.id })
        return uniqueExercises.count
    }

    private var averageIntensity: Double? {
        guard totalReps > 0 else { return nil }
        return totalMovedWeight / Double(totalReps)
    }

    private struct ExerciseVolume {
        let exercise: Exercise
        let volume: Double
    }

    private var exerciseVolumeBreakdown: [ExerciseVolume] {
        guard let sets = session.sets else { return [] }

        var volumeMap: [UUID: (exercise: Exercise, volume: Double)] = [:]

        for set in sets {
            if let exercise = set.exercise, let weight = set.weight, let reps = set.reps {
                let volume = weight * Double(reps)
                if let existing = volumeMap[exercise.id] {
                    volumeMap[exercise.id] = (exercise, existing.volume + volume)
                } else {
                    volumeMap[exercise.id] = (exercise, volume)
                }
            }
        }

        return volumeMap.values
            .map { ExerciseVolume(exercise: $0.exercise, volume: $0.volume) }
            .sorted { $0.volume > $1.volume }
    }

    private func exerciseVolume(for exercise: Exercise) -> Double? {
        guard let sets = session.sets else { return nil }

        let volume = sets
            .filter { $0.exercise?.id == exercise.id }
            .reduce(0.0) { total, set in
                if let weight = set.weight, let reps = set.reps {
                    return total + (weight * Double(reps))
                }
                return total
            }

        return volume > 0 ? volume : nil
    }

    private struct PersonalRecord {
        let exercise: Exercise
        let weight: Double
        let reps: Int
    }

    private var personalRecords: [PersonalRecord] {
        guard let sets = session.sets else { return [] }

        var records: [PersonalRecord] = []

        // Group sets by exercise
        let exerciseGroups = Dictionary(grouping: sets.compactMap { set -> (Exercise, WorkoutSet)? in
            guard let exercise = set.exercise else { return nil }
            return (exercise, set)
        }, by: { $0.0.id })

        for (exerciseId, exerciseSets) in exerciseGroups {
            guard let exercise = exerciseSets.first?.0 else { continue }

            // Get all historical sets for this exercise (excluding current session)
            let historicalSets = allSessions
                .filter { $0.id != session.id }
                .flatMap { $0.sets ?? [] }
                .filter { $0.exercise?.id == exerciseId }

            // Find max weight × reps in this session
            if let sessionMax = exerciseSets
                .compactMap({ set -> (weight: Double, reps: Int)? in
                    guard let weight = set.1.weight, let reps = set.1.reps else { return nil }
                    return (weight, reps)
                })
                .max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) {

                // Check if this beats historical max
                let historicalMax = historicalSets
                    .compactMap({ set -> Double? in
                        guard let weight = set.weight, let reps = set.reps else { return nil }
                        return weight * Double(reps)
                    })
                    .max() ?? 0

                let sessionMaxVolume = sessionMax.weight * Double(sessionMax.reps)

                if sessionMaxVolume > historicalMax {
                    records.append(PersonalRecord(
                        exercise: exercise,
                        weight: sessionMax.weight,
                        reps: sessionMax.reps
                    ))
                }
            }
        }

        return records
    }

    private struct WorkoutComparison {
        let totalWeight: Double
        let totalReps: Int
        let duration: TimeInterval
    }

    private var previousWorkoutComparison: WorkoutComparison? {
        guard let splitId = session.splitId else { return nil }

        // Find previous workout with same split
        let previousSession = allSessions
            .filter { $0.splitId == splitId && $0.id != session.id && $0.startTime < session.startTime }
            .sorted { $0.startTime > $1.startTime }
            .first

        guard let previous = previousSession, let previousSets = previous.sets else { return nil }

        let totalWeight = previousSets.reduce(0.0) { total, set in
            if let weight = set.weight, let reps = set.reps {
                return total + (weight * Double(reps))
            }
            return total
        }

        let totalReps = previousSets.reduce(0) { total, set in
            total + (set.reps ?? 0)
        }

        let duration = previous.endTime?.timeIntervalSince(previous.startTime) ?? 0

        return WorkoutComparison(totalWeight: totalWeight, totalReps: totalReps, duration: duration)
    }

    private var insights: [String] {
        var insights: [String] = []

        // Workout duration insight
        if let duration = session.endTime?.timeIntervalSince(session.startTime) {
            let minutes = Int(duration / 60)
            if minutes < 30 {
                insights.append("Quick workout - under 30 minutes")
            } else if minutes > 90 {
                insights.append("Extended session - over 90 minutes")
            }
        }

        // Volume insight
        if totalMovedWeight > 5000 {
            insights.append("High volume workout - moved over 5 tons")
        }

        // Exercise variety
        if uniqueExerciseCount >= 8 {
            insights.append("Great exercise variety with \(uniqueExerciseCount) different movements")
        }

        // Note: Consistency with targets insight removed - requires split relationship access
        // which can crash on orphaned data. Could be re-added if exercise targets are stored on WorkoutSet.

        // Personal records
        if !personalRecords.isEmpty {
            insights.append("Set \(personalRecords.count) personal record\(personalRecords.count > 1 ? "s" : "") this workout")
        }

        // Comparison insight
        if let comparison = previousWorkoutComparison {
            let weightDiff = ((totalMovedWeight - comparison.totalWeight) / comparison.totalWeight) * 100
            if weightDiff > 10 {
                insights.append(String(format: "Total volume increased by %.0f%% from last workout", weightDiff))
            } else if weightDiff < -10 {
                insights.append(String(format: "Total volume decreased by %.0f%% from last workout", abs(weightDiff)))
            }
        }

        if insights.isEmpty {
            insights.append("Solid workout - keep up the consistency")
        }

        return insights
    }

    private func getOrderedExercises() -> [Exercise]? {
        guard let sets = session.sets, !sets.isEmpty else { return nil }

        let sortedSets = sets.sorted { $0.startTime < $1.startTime }
        var seenIds = Set<UUID>()
        var orderedExercises: [Exercise] = []

        for set in sortedSets {
            if let exercise = set.exercise, !seenIds.contains(exercise.id) {
                orderedExercises.append(exercise)
                seenIds.insert(exercise.id)
            }
        }

        return orderedExercises.isEmpty ? nil : orderedExercises
    }

    private func getSetsForExercise(_ exercise: Exercise) -> [WorkoutSet]? {
        guard let sets = session.sets else { return nil }

        let exerciseSets = sets
            .filter { $0.exercise?.id == exercise.id }
            .sorted { $0.startTime < $1.startTime }

        return exerciseSets.isEmpty ? nil : exerciseSets
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
                .font(.subheadline)
                .fontWeight(.semibold)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)

                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(color.opacity(0.1))
        .cornerRadius(12)
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
            return difference < 0 // Shorter duration is better
        } else {
            return difference > 0 // More is better
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
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
            .modelContainer(for: [WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self])
    }
}
