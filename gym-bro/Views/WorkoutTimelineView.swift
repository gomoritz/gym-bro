//
//  WorkoutTimelineView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 13.01.26.
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
                VStack(alignment: .leading, spacing: 20) {
                    if sessionManager.activeSession != nil {
                        // Prediction overview
                        if let prediction = prediction {
                            predictionOverview(prediction)
                        }

                        // Progress bar
                        workoutProgressBar

                        // Completed exercises
                        if let completedExercises = getCompletedExercises(), !completedExercises.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(completedExercises, id: \.id) { exercise in
                                        completedExerciseView(exercise)
                                    }
                                }
                            } header: {
                                sectionHeader(title: "Completed", icon: "checkmark.circle.fill", color: .green)
                            }
                        }

                        // Current exercise
                        if let current = sessionManager.currentExercise {
                            Section {
                                currentExerciseView(current)
                            } header: {
                                sectionHeader(title: "Current", icon: "play.circle.fill", color: .orange)
                            }
                        }

                        // Remaining exercises with predictions
                        if !sessionManager.remainingExercisesInSplit.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
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
        VStack(spacing: 16) {
            // Main prediction card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated Completion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let completionTime = prediction.estimatedCompletionTime {
                            Text(completionTime, style: .time)
                                .font(.title)
                                .fontWeight(.bold)
                        } else {
                            Text("Calculating...")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Time Remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let remaining = prediction.timeRemaining {
                            Text(formatTimeRemaining(remaining))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Confidence and pace indicators
                HStack(spacing: 16) {
                    confidenceIndicator(prediction.confidence)

                    if let paceInfo = prediction.paceInfo {
                        paceIndicator(paceInfo)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            // Historical comparison
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
        .background(confidence.color.opacity(0.15))
        .cornerRadius(8)
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func historicalComparisonView(_ comparison: HistoricalComparison) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.purple)

                Text("Based on \(comparison.sessionCount) previous workout\(comparison.sessionCount > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Show enhanced data badge if available
                if hasEnhancedDataInPrediction {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Enhanced")
                            .font(.caption2)
                    }
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(6)
                }
            }

            if let avgDuration = comparison.averageDuration {
                HStack {
                    Text("Typical duration:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatDuration(avgDuration))
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    if let range = comparison.durationRange {
                        Text("\(formatDuration(range.min)) - \(formatDuration(range.max))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Show days since last workout if available
            if let daysSince = daysSinceLastWorkout {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("\(daysSince) day\(daysSince > 1 ? "s" : "") since last workout")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }

    private var hasEnhancedDataInPrediction: Bool {
        guard let prediction = prediction else { return false }
        return prediction.exercisePredictions.values.contains { $0.hasEnhancedData }
    }

    private var daysSinceLastWorkout: Int? {
        guard let split = sessionManager.currentSplit else { return nil }

        let previousSessions = allSessions.filter { session in
            session.split?.id == split.id &&
            session.id != sessionManager.activeSession?.id &&
            session.startTime < (sessionManager.activeSession?.startTime ?? Date())
        }.sorted { $0.startTime > $1.startTime }

        guard let lastSession = previousSessions.first,
              let currentStart = sessionManager.activeSession?.startTime else { return nil }

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastSession.startTime, to: currentStart).day
        return days
    }

    // MARK: - Progress Bar

    private var workoutProgressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Workout Progress")
                    .font(.headline)

                Spacer()

                if let progress = calculateWorkoutProgress() {
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    if let progress = calculateWorkoutProgress() {
                        RoundedRectangle(cornerRadius: 8)
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
        .padding(.vertical, 8)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - View Components

    private func completedExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .font(.caption)
                        .fontWeight(.semibold)
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
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }

    private func currentExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("~\(formatDuration(avgTime))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // Show already logged sets for current exercise
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
                    } else {
                        Text("Set \(sessionManager.currentSetNumber)")
                            .font(.subheadline)
                    }
                } icon: {
                    Image(systemName: "list.number")
                }

                Spacer()

                if let targetWeight = exercise.targetWeight,
                   let minReps = exercise.minReps,
                   let maxReps = exercise.maxReps {
                    Text("\(String(format: "%.1f", targetWeight))kg × \(minReps)-\(maxReps)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 32)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private func remainingExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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
                        Text("\(String(format: "%.1f", targetWeight))kg × \(minReps)-\(maxReps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                }

                Spacer()

                // Show prediction for this exercise
                if let exercisePred = prediction?.exercisePredictions[exercise.id] {
                    VStack(alignment: .trailing, spacing: 4) {
                        if let duration = exercisePred.estimatedDuration {
                            HStack(spacing: 4) {
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
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func setRowView(_ workoutSet: WorkoutSet, setNumber: Int, exercise: Exercise) -> some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            if let weight = workoutSet.weight, let reps = workoutSet.reps {
                Text("\(String(format: "%.1f", weight))kg × \(reps)")
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if let duration = workoutSet.duration {
                Text("\(duration) min")
                    .font(.caption)
                    .fontWeight(.semibold)
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
        let current = sessionManager.currentExercise != nil ? 1 : 0
        let total = exercises.count

        guard total > 0 else { return nil }

        // Calculate progress including partial progress on current exercise
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

        // Return in order of first appearance in sets (sorted by time)
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

// MARK: - Workout Predictor

class WorkoutPredictor {
    let currentSession: WorkoutSession
    let split: Split
    let allSessions: [WorkoutSession]
    let completedExercises: [Exercise]
    let currentExercise: Exercise?
    let remainingExercises: [Exercise]

    init(
        currentSession: WorkoutSession,
        split: Split,
        allSessions: [WorkoutSession],
        completedExercises: [Exercise],
        currentExercise: Exercise?,
        remainingExercises: [Exercise]
    ) {
        self.currentSession = currentSession
        self.split = split
        self.allSessions = allSessions
        self.completedExercises = completedExercises
        self.currentExercise = currentExercise
        self.remainingExercises = remainingExercises
    }

    func generatePrediction() -> WorkoutPrediction {
        let historicalSessions = getHistoricalSessions()
        let exercisePredictions = predictExercises()
        let confidence = calculateConfidence(historicalSessions: historicalSessions)

        // Calculate time remaining
        var timeRemaining: TimeInterval = 0

        // Add remaining time for current exercise
        if let current = currentExercise,
           let currentPred = exercisePredictions[current.id],
           let estimatedDuration = currentPred.estimatedDuration {
            // Estimate remaining time based on sets completed
            let currentSets = currentSession.sets?.filter { $0.exercise?.id == current.id }.count ?? 0
            let totalSets = currentPred.estimatedSets ?? 3
            if totalSets > currentSets {
                let progressRatio = Double(totalSets - currentSets) / Double(totalSets)
                timeRemaining += estimatedDuration * progressRatio
            }
        }

        // Add time for remaining exercises
        for exercise in remainingExercises {
            if let pred = exercisePredictions[exercise.id],
               let duration = pred.estimatedDuration {
                // Account for skip probability - if >50% skip rate, reduce confidence
                let adjustedDuration = duration * (1.0 - (pred.skipProbability * 0.5))
                timeRemaining += adjustedDuration

                // Add transition time - use historical average if available
                let transitionTime = calculateAverageTransitionTime() ?? 60
                timeRemaining += transitionTime
            }
        }

        let estimatedCompletionTime = timeRemaining > 0 ? Date().addingTimeInterval(timeRemaining) : nil

        // Calculate pace info
        let paceInfo = calculatePaceInfo(historicalSessions: historicalSessions)

        // Historical comparison
        let historicalComparison = calculateHistoricalComparison(historicalSessions: historicalSessions)

        return WorkoutPrediction(
            estimatedCompletionTime: estimatedCompletionTime,
            timeRemaining: timeRemaining > 0 ? timeRemaining : nil,
            confidence: confidence,
            exercisePredictions: exercisePredictions,
            paceInfo: paceInfo,
            historicalComparison: historicalComparison
        )
    }

    private func getHistoricalSessions() -> [WorkoutSession] {
        let baseSessions = allSessions.filter { session in
            session.id != currentSession.id &&
            session.split?.id == split.id &&
            session.endTime != nil
        }

        // Sort by recency (most recent first) for weighted calculations later
        return baseSessions.sorted { $0.startTime > $1.startTime }
    }

    private func getTimeAdjustedSessions(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        // Filter sessions by similar time of day (within 3 hours)
        let currentHour = currentSession.timeOfDay
        return sessions.filter { session in
            let hourDiff = abs(session.timeOfDay - currentHour)
            return hourDiff <= 3 || hourDiff >= 21  // Account for wrap-around (23:00 vs 01:00)
        }
    }

    private func getDaysSinceLastWorkout() -> Int? {
        let previousSessions = allSessions.filter { session in
            session.id != currentSession.id &&
            session.split?.id == split.id &&
            session.startTime < currentSession.startTime
        }.sorted { $0.startTime > $1.startTime }

        guard let lastSession = previousSessions.first else { return nil }

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastSession.startTime, to: currentSession.startTime).day
        return days
    }

    private func predictExercises() -> [UUID: ExercisePrediction] {
        var predictions: [UUID: ExercisePrediction] = [:]

        let historicalSessions = getHistoricalSessions()

        // Predict for current exercise
        if let current = currentExercise {
            predictions[current.id] = predictExercise(current, in: historicalSessions)
        }

        // Predict for remaining exercises
        for exercise in remainingExercises {
            predictions[exercise.id] = predictExercise(exercise, in: historicalSessions)
        }

        return predictions
    }

    private func predictExercise(_ exercise: Exercise, in sessions: [WorkoutSession]) -> ExercisePrediction {
        var durations: [TimeInterval] = []
        var setCounts: [Int] = []
        var hasEnhancedData = false

        // Check if exercise is frequently skipped
        let skipCount = sessions.filter { session in
            session.skippedExerciseIds?.contains(exercise.id) ?? false
        }.count

        // If exercise is skipped >50% of the time, mark it
        let skipProbability = sessions.isEmpty ? 0.0 : Double(skipCount) / Double(sessions.count)

        // Prefer time-adjusted sessions if we have enough data
        var relevantSessions = sessions
        let timeAdjusted = getTimeAdjustedSessions(sessions)
        if timeAdjusted.count >= 3 {
            relevantSessions = timeAdjusted
        }

        // Collect historical data for this specific exercise
        for (index, session) in relevantSessions.enumerated() {
            guard let sets = session.sets else { continue }

            let exerciseSets = sets
                .filter { $0.exercise?.id == exercise.id }
                .sorted { $0.startTime < $1.startTime }

            guard exerciseSets.count >= 1 else { continue }

            // Weight more recent sessions higher (exponential decay)
            let recencyWeight = pow(0.9, Double(index))

            setCounts.append(exerciseSets.count)

            // Calculate duration using enhanced data if available
            var exerciseDuration: TimeInterval?

            if exerciseSets.count >= 2,
               let firstSetEnd = exerciseSets.first?.endTime,
               let lastSetStart = exerciseSets.last?.startTime {
                // Use endTime of first set to startTime of last set for more accurate duration
                exerciseDuration = lastSetStart.timeIntervalSince(firstSetEnd)
                hasEnhancedData = true
            } else if exerciseSets.count >= 2 {
                // Fallback to old method
                let firstSet = exerciseSets.first!
                let lastSet = exerciseSets.last!
                exerciseDuration = lastSet.startTime.timeIntervalSince(firstSet.startTime)
            } else if exerciseSets.count == 1 {
                // Single set - estimate based on rest timer or default
                if let restDuration = exerciseSets.first?.restDuration {
                    exerciseDuration = restDuration
                    hasEnhancedData = true
                } else {
                    exerciseDuration = 30
                }
            }

            if let duration = exerciseDuration {
                // Apply recency weighting to duration
                durations.append(duration * recencyWeight)
            }
        }

        // Calculate weighted averages
        let estimatedDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
        let estimatedSets = setCounts.isEmpty ? exercise.targetSets : Int(Double(setCounts.reduce(0, +)) / Double(setCounts.count))

        // Adjust for rest recovery patterns (days since last workout)
        var adjustedDuration = estimatedDuration
        if let daysSince = getDaysSinceLastWorkout(),
           let duration = estimatedDuration {
            // More rest = slightly longer workouts (more sets/energy)
            if daysSince >= 4 {
                adjustedDuration = duration * 1.1  // 10% longer
            } else if daysSince <= 1 {
                adjustedDuration = duration * 0.95  // 5% shorter (fatigue)
            }
        }

        return ExercisePrediction(
            exerciseId: exercise.id,
            estimatedDuration: adjustedDuration,
            estimatedSets: estimatedSets,
            historicalSampleSize: relevantSessions.count,
            skipProbability: skipProbability,
            hasEnhancedData: hasEnhancedData
        )
    }

    private func calculateConfidence(historicalSessions: [WorkoutSession]) -> PredictionConfidence {
        let count = historicalSessions.count

        if count >= 10 {
            return .high
        } else if count >= 3 {
            return .medium
        } else if count >= 1 {
            return .low
        } else {
            return .none
        }
    }

    private func calculatePaceInfo(historicalSessions: [WorkoutSession]) -> PaceInfo? {
        guard !historicalSessions.isEmpty else { return nil }

        // Calculate current session progress rate (exercises per minute)
        let currentElapsed = Date().timeIntervalSince(currentSession.startTime)
        guard currentElapsed > 0 else { return nil }

        let currentProgress = completedExercises.count
        let currentRate = Double(currentProgress) / (currentElapsed / 60.0)

        // Calculate historical average rate
        var historicalRates: [Double] = []

        for session in historicalSessions {
            guard let endTime = session.endTime,
                  let sets = session.sets else { continue }

            let duration = endTime.timeIntervalSince(session.startTime)
            let uniqueExercises = Set(sets.compactMap { $0.exercise?.id }).count

            if duration > 0 {
                let rate = Double(uniqueExercises) / (duration / 60.0)
                historicalRates.append(rate)
            }
        }

        guard !historicalRates.isEmpty else { return nil }

        let avgRate = historicalRates.reduce(0, +) / Double(historicalRates.count)

        // Compare current rate to historical average
        let paceFactor = currentRate / avgRate

        return PaceInfo(
            paceFactor: paceFactor,
            isAhead: paceFactor > 1.1,
            isBehind: paceFactor < 0.9
        )
    }

    private func calculateHistoricalComparison(historicalSessions: [WorkoutSession]) -> HistoricalComparison? {
        guard !historicalSessions.isEmpty else { return nil }

        var durations: [TimeInterval] = []

        for session in historicalSessions {
            if let endTime = session.endTime {
                let duration = endTime.timeIntervalSince(session.startTime)
                durations.append(duration)
            }
        }

        guard !durations.isEmpty else { return nil }

        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let minDuration = durations.min()
        let maxDuration = durations.max()

        let range: (min: TimeInterval, max: TimeInterval)? = {
            if let min = minDuration, let max = maxDuration {
                return (min, max)
            }
            return nil
        }()

        return HistoricalComparison(
            sessionCount: historicalSessions.count,
            averageDuration: avgDuration,
            durationRange: range
        )
    }

    private func calculateAverageTransitionTime() -> TimeInterval? {
        let historicalSessions = getHistoricalSessions()
        var transitionTimes: [TimeInterval] = []

        for session in historicalSessions {
            guard let sets = session.sets,
                  let order = session.actualExerciseOrder,
                  order.count >= 2 else { continue }

            // Calculate time between last set of one exercise and first set of next
            for i in 0..<(order.count - 1) {
                let currentExerciseId = order[i]
                let nextExerciseId = order[i + 1]

                let currentExerciseSets = sets.filter { $0.exercise?.id == currentExerciseId }
                    .sorted { $0.startTime < $1.startTime }
                let nextExerciseSets = sets.filter { $0.exercise?.id == nextExerciseId }
                    .sorted { $0.startTime < $1.startTime }

                if let lastSet = currentExerciseSets.last,
                   let firstSet = nextExerciseSets.first {
                    // Use endTime if available, otherwise use startTime
                    let transitionStart = lastSet.endTime ?? lastSet.startTime
                    let transitionTime = firstSet.startTime.timeIntervalSince(transitionStart)

                    // Only count reasonable transitions (10s to 5min)
                    if transitionTime >= 10 && transitionTime <= 300 {
                        transitionTimes.append(transitionTime)
                    }
                }
            }
        }

        guard !transitionTimes.isEmpty else { return nil }
        return transitionTimes.reduce(0, +) / Double(transitionTimes.count)
    }
}

// MARK: - Prediction Models

struct WorkoutPrediction {
    let estimatedCompletionTime: Date?
    let timeRemaining: TimeInterval?
    let confidence: PredictionConfidence
    let exercisePredictions: [UUID: ExercisePrediction]
    let paceInfo: PaceInfo?
    let historicalComparison: HistoricalComparison?
}

struct ExercisePrediction {
    let exerciseId: UUID
    let estimatedDuration: TimeInterval?
    let estimatedSets: Int?
    let historicalSampleSize: Int
    let skipProbability: Double
    let hasEnhancedData: Bool
}

enum PredictionConfidence {
    case none, low, medium, high

    var label: String {
        switch self {
        case .none: return "No data"
        case .low: return "Low confidence"
        case .medium: return "Medium confidence"
        case .high: return "High confidence"
        }
    }

    var icon: String {
        switch self {
        case .none: return "questionmark.circle"
        case .low: return "circle.dotted"
        case .medium: return "circle.lefthalf.filled"
        case .high: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .none: return .gray
        case .low: return .orange
        case .medium: return .blue
        case .high: return .green
        }
    }
}

struct PaceInfo {
    let paceFactor: Double
    let isAhead: Bool
    let isBehind: Bool

    var description: String {
        if isAhead {
            return "Faster pace"
        } else if isBehind {
            return "Slower pace"
        } else {
            return "On pace"
        }
    }
}

struct HistoricalComparison {
    let sessionCount: Int
    let averageDuration: TimeInterval?
    let durationRange: (min: TimeInterval, max: TimeInterval)?
}

#Preview {
    let manager = SessionManager()
    return WorkoutTimelineView(sessionManager: manager)
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self])
}
