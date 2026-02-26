//
//  WorkoutTimelineView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 13.01.26.
//

import SwiftUI
import SwiftData

struct WorkoutTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allSessions: [WorkoutSession]

    var sessionManager: SessionManager

    @State private var predictor: WorkoutPredictor?
    @State private var prediction: WorkoutPrediction?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if sessionManager.activeSession != nil {
                        if let prediction = prediction {
                            predictionOverview(prediction)
                        }

                        workoutProgressBar

                        if let completedExercises = getCompletedExercises(), !completedExercises.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    ForEach(completedExercises, id: \.id) { exercise in
                                        completedExerciseView(exercise)
                                    }
                                }
                            } header: {
                                sectionHeader(title: "Completed", icon: "checkmark.circle.fill", color: .green)
                            }
                        }

                        if let current = sessionManager.currentExercise {
                            Section {
                                currentExerciseView(current)
                            } header: {
                                sectionHeader(title: "Current", icon: "play.circle.fill", color: .orange)
                            }
                        }

                        if !sessionManager.remainingExercisesInSplit.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    ForEach(sessionManager.remainingExercisesInSplit) { exercise in
                                        remainingExerciseView(exercise)
                                    }
                                }
                            } header: {
                                sectionHeader(title: "Remaining", icon: "circle", color: .gray)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                updatePrediction()
            }
            .onChange(of: sessionManager.activeSession?.sets?.count ?? 0) { _, _ in
                updatePrediction()
            }
        }
    }

    // MARK: - Prediction Overview

    private func predictionOverview(_ prediction: WorkoutPrediction) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Estimated Completion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let completionTime = prediction.estimatedCompletionTime {
                            Text(completionTime, style: .time)
                                .font(.system(.title, design: .rounded, weight: .bold))
                        } else {
                            Text("Calculating...")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                        Text("Time Remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let remaining = prediction.timeRemaining {
                            Text(formatTimeRemaining(remaining))
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }

                HStack(spacing: Theme.Spacing.lg) {
                    confidenceIndicator(prediction.confidence)

                    if let paceInfo = prediction.paceInfo {
                        paceIndicator(paceInfo)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

            if let historical = prediction.historicalComparison {
                historicalComparisonView(historical)
            }
        }
    }

    private func confidenceIndicator(_ confidence: PredictionConfidence) -> some View {
        HStack(spacing: 6) {
            Image(systemName: confidence.icon)
                .foregroundStyle(confidence.color)

            Text(confidence.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if confidence != .high {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(confidence.color.opacity(0.15), in: Capsule())
    }

    private func paceIndicator(_ pace: PaceInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: pace.isAhead ? "hare.fill" : pace.isBehind ? "tortoise.fill" : "equal.circle.fill")
                .foregroundStyle(pace.isAhead ? .green : pace.isBehind ? .orange : .gray)

            Text(pace.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func historicalComparisonView(_ comparison: HistoricalComparison) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)

                Text("Based on \(comparison.sessionCount) previous workout\(comparison.sessionCount > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if hasEnhancedDataInPrediction {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Enhanced")
                            .font(.caption2)
                    }
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2), in: Capsule())
                }
            }

            if let avgDuration = comparison.averageDuration {
                HStack {
                    Text("Typical duration:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatDuration(avgDuration))
                        .font(.system(.caption, design: .rounded, weight: .semibold))

                    Spacer()

                    if let range = comparison.durationRange {
                        Text("\(formatDuration(range.min)) - \(formatDuration(range.max))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let daysSince = daysSinceLastWorkout {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("\(daysSince) day\(daysSince > 1 ? "s" : "") since last workout")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private var hasEnhancedDataInPrediction: Bool {
        guard let prediction = prediction else { return false }
        return prediction.exercisePredictions.values.contains { $0.hasEnhancedData }
    }

    private var daysSinceLastWorkout: Int? {
        guard let split = sessionManager.currentSplit else { return nil }

        let previousSessions = allSessions.filter { session in
            session.splitId == split.id &&
            session.id != sessionManager.activeSession?.id &&
            session.startTime < (sessionManager.activeSession?.startTime ?? Date())
        }.sorted { $0.startTime > $1.startTime }

        guard let lastSession = previousSessions.first,
              let currentStart = sessionManager.activeSession?.startTime else { return nil }

        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: lastSession.startTime, to: currentStart).day
    }

    // MARK: - Progress Bar

    private var workoutProgressBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Workout Progress")
                    .font(.system(.headline, design: .rounded))

                Spacer()

                if let progress = calculateWorkoutProgress() {
                    Text("\(Int(progress * 100))%")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.blue)
                        .contentTransition(.numericText())
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .fill(.tertiary.opacity(0.3))
                        .frame(height: 12)

                    if let progress = calculateWorkoutProgress() {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 12)
                            .animation(.spring(response: 0.3), value: progress)
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(.system(.headline, design: .rounded))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - View Components

    private func completedExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label {
                    Text(exercise.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Spacer()

                if let duration = exerciseDuration(for: exercise) {
                    Text(formatDuration(duration))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let sets = getSetsForExercise(exercise) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sets.indices, id: \.self) { index in
                        setRowView(sets[index], setNumber: index + 1, exercise: exercise)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func currentExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label {
                    Text(exercise.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.orange)
                }

                Spacer()

                if let avgTime = prediction?.exercisePredictions[exercise.id]?.estimatedDuration {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("~\(formatDuration(avgTime))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if let sets = getSetsForExercise(exercise) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sets.indices, id: \.self) { index in
                        setRowView(sets[index], setNumber: index + 1, exercise: exercise)
                    }
                }
                .padding(.leading, 32)
            }

            HStack {
                Label {
                    if let targetSets = exercise.targetSets {
                        Text("Set \(sessionManager.currentSetNumber) of \(targetSets)")
                            .font(.subheadline)
                            .contentTransition(.numericText())
                    } else {
                        Text("Set \(sessionManager.currentSetNumber)")
                            .font(.subheadline)
                            .contentTransition(.numericText())
                    }
                } icon: {
                    Image(systemName: "list.number")
                }

                Spacer()

                if let targetWeight = exercise.targetWeight,
                   let minReps = exercise.minReps,
                   let maxReps = exercise.maxReps {
                    Text("\(String(format: "%.1f", targetWeight))kg x \(minReps)-\(maxReps)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 32)
        }
        .padding(Theme.Spacing.lg)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func remainingExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Label {
                        Text(exercise.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "circle")
                            .foregroundStyle(.gray)
                    }

                    if let targetWeight = exercise.targetWeight,
                       let minReps = exercise.minReps,
                       let maxReps = exercise.maxReps {
                        Text("\(String(format: "%.1f", targetWeight))kg x \(minReps)-\(maxReps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                }

                Spacer()

                if let exercisePred = prediction?.exercisePredictions[exercise.id] {
                    VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                        if let duration = exercisePred.estimatedDuration {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("~\(formatDuration(duration))")
                                    .font(.caption)
                            }
                        }

                        if let sets = exercisePred.estimatedSets {
                            Text("~\(sets) set\(sets > 1 ? "s" : "")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    private func setRowView(_ workoutSet: WorkoutSet, setNumber: Int, exercise: Exercise) -> some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            if let weight = workoutSet.weight, let reps = workoutSet.reps {
                Text("\(String(format: "%.1f", weight))kg x \(reps)")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            } else if let duration = workoutSet.duration {
                Text("\(duration) min")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }

            Spacer()

            Text(timeAgoString(from: workoutSet.startTime))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func updatePrediction() {
        guard let session = sessionManager.activeSession,
              let split = sessionManager.currentSplit else {
            prediction = nil
            return
        }

        let pred = WorkoutPredictor(
            currentSession: session,
            split: split,
            allSessions: allSessions,
            completedExercises: getCompletedExercises() ?? [],
            currentExercise: sessionManager.currentExercise,
            remainingExercises: sessionManager.remainingExercisesInSplit
        )

        self.predictor = pred
        self.prediction = pred.generatePrediction()
    }

    private func calculateWorkoutProgress() -> Double? {
        guard let split = sessionManager.currentSplit,
              let exercises = split.exercises,
              !exercises.isEmpty else {
            return nil
        }

        let completed = getCompletedExercises()?.count ?? 0
        let total = exercises.count

        guard total > 0 else { return nil }

        var progress = Double(completed) / Double(total)

        if let currentEx = sessionManager.currentExercise,
           let targetSets = currentEx.targetSets,
           targetSets > 0 {
            let currentSetProgress = Double(sessionManager.currentSetNumber - 1) / Double(targetSets)
            progress += currentSetProgress / Double(total)
        }

        return min(progress, 1.0)
    }

    private func exerciseDuration(for exercise: Exercise) -> TimeInterval? {
        guard let sets = getSetsForExercise(exercise),
              sets.count >= 2 else {
            return nil
        }

        let firstSet = sets.first!
        let lastSet = sets.last!
        return lastSet.startTime.timeIntervalSince(firstSet.startTime)
    }

    private func getCompletedExercises() -> [Exercise]? {
        guard let session = sessionManager.activeSession,
              let sets = session.sets,
              let split = sessionManager.currentSplit,
              let exercises = split.exercises else {
            return nil
        }

        let currentExerciseId = sessionManager.currentExercise?.id
        let completedIds = Set(sets.compactMap { $0.exercise?.id }.filter { $0 != currentExerciseId })
        let completedExercises = exercises.filter { completedIds.contains($0.id) }

        let sortedSets = sets.sorted { $0.startTime < $1.startTime }
        var seenIds = Set<UUID>()
        var orderedExercises: [Exercise] = []

        for set in sortedSets {
            if let exerciseId = set.exercise?.id,
               exerciseId != currentExerciseId,
               !seenIds.contains(exerciseId) {
                if let exercise = completedExercises.first(where: { $0.id == exerciseId }) {
                    orderedExercises.append(exercise)
                }
                seenIds.insert(exerciseId)
            }
        }

        return orderedExercises.isEmpty ? nil : orderedExercises
    }

    private func getSetsForExercise(_ exercise: Exercise) -> [WorkoutSet]? {
        guard let session = sessionManager.activeSession,
              let sets = session.sets else {
            return nil
        }

        let exerciseSets = sets.filter { $0.exercise?.id == exercise.id }
            .sorted { $0.startTime < $1.startTime }
        return exerciseSets.isEmpty ? nil : exerciseSets
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else if minutes > 0 {
            return "\(minutes)m left"
        } else {
            return "Almost done!"
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

#Preview {
    let manager = SessionManager()
    return WorkoutTimelineView(sessionManager: manager)
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self])
}
