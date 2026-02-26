//
//  WorkoutPredictor.swift
//  gym-bro
//

import Foundation
import SwiftUI

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
                let adjustedDuration = duration * (1.0 - (pred.skipProbability * Constants.Prediction.skipProbabilityDampeningFactor))
                timeRemaining += adjustedDuration

                let transitionTime = calculateAverageTransitionTime() ?? Constants.Timer.defaultTransitionDuration
                timeRemaining += transitionTime
            }
        }

        let estimatedCompletionTime = timeRemaining > 0 ? Date().addingTimeInterval(timeRemaining) : nil
        let paceInfo = calculatePaceInfo(historicalSessions: historicalSessions)
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
            session.splitId == split.id &&
            session.endTime != nil
        }
        return baseSessions.sorted { $0.startTime > $1.startTime }
    }

    private func getTimeAdjustedSessions(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        let currentHour = currentSession.timeOfDay
        return sessions.filter { session in
            let hourDiff = abs(session.timeOfDay - currentHour)
            return hourDiff <= Constants.Prediction.timeOfDayWindowHours || hourDiff >= (24 - Constants.Prediction.timeOfDayWindowHours)
        }
    }

    private func getDaysSinceLastWorkout() -> Int? {
        let previousSessions = allSessions.filter { session in
            session.id != currentSession.id &&
            session.splitId == split.id &&
            session.startTime < currentSession.startTime
        }.sorted { $0.startTime > $1.startTime }

        guard let lastSession = previousSessions.first else { return nil }

        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: lastSession.startTime, to: currentSession.startTime).day
    }

    private func predictExercises() -> [UUID: ExercisePrediction] {
        var predictions: [UUID: ExercisePrediction] = [:]
        let historicalSessions = getHistoricalSessions()

        if let current = currentExercise {
            predictions[current.id] = predictExercise(current, in: historicalSessions)
        }

        for exercise in remainingExercises {
            predictions[exercise.id] = predictExercise(exercise, in: historicalSessions)
        }

        return predictions
    }

    private func predictExercise(_ exercise: Exercise, in sessions: [WorkoutSession]) -> ExercisePrediction {
        var durations: [TimeInterval] = []
        var setCounts: [Int] = []
        var hasEnhancedData = false

        let skipCount = sessions.filter { session in
            session.skippedExerciseIds?.contains(exercise.id) ?? false
        }.count

        let skipProbability = sessions.isEmpty ? 0.0 : Double(skipCount) / Double(sessions.count)

        var relevantSessions = sessions
        let timeAdjusted = getTimeAdjustedSessions(sessions)
        if timeAdjusted.count >= Constants.Prediction.mediumConfidenceThreshold {
            relevantSessions = timeAdjusted
        }

        for (index, session) in relevantSessions.enumerated() {
            guard let sets = session.sets else { continue }

            let exerciseSets = sets
                .filter { $0.exercise?.id == exercise.id }
                .sorted { $0.startTime < $1.startTime }

            guard exerciseSets.count >= 1 else { continue }

            let recencyWeight = pow(Constants.Prediction.recencyDecayFactor, Double(index))
            setCounts.append(exerciseSets.count)

            var exerciseDuration: TimeInterval?

            if exerciseSets.count >= 2,
               let firstSetEnd = exerciseSets.first?.endTime,
               let lastSetStart = exerciseSets.last?.startTime {
                exerciseDuration = lastSetStart.timeIntervalSince(firstSetEnd)
                hasEnhancedData = true
            } else if exerciseSets.count >= 2 {
                let firstSet = exerciseSets.first!
                let lastSet = exerciseSets.last!
                exerciseDuration = lastSet.startTime.timeIntervalSince(firstSet.startTime)
            } else if exerciseSets.count == 1 {
                if let restDuration = exerciseSets.first?.restDuration {
                    exerciseDuration = restDuration
                    hasEnhancedData = true
                } else {
                    exerciseDuration = Constants.Prediction.singleSetFallbackDuration
                }
            }

            if let duration = exerciseDuration {
                durations.append(duration * recencyWeight)
            }
        }

        let estimatedDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
        let estimatedSets = setCounts.isEmpty ? exercise.targetSets : Int(Double(setCounts.reduce(0, +)) / Double(setCounts.count))

        var adjustedDuration = estimatedDuration
        if let daysSince = getDaysSinceLastWorkout(),
           let duration = estimatedDuration {
            if daysSince >= Constants.Prediction.longRestDaysThreshold {
                adjustedDuration = duration * Constants.Prediction.longRestDurationMultiplier
            } else if daysSince <= Constants.Prediction.shortRestDaysThreshold {
                adjustedDuration = duration * Constants.Prediction.shortRestDurationMultiplier
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

        if count >= Constants.Prediction.highConfidenceThreshold {
            return .high
        } else if count >= Constants.Prediction.mediumConfidenceThreshold {
            return .medium
        } else if count >= Constants.Prediction.lowConfidenceThreshold {
            return .low
        } else {
            return .none
        }
    }

    private func calculatePaceInfo(historicalSessions: [WorkoutSession]) -> PaceInfo? {
        guard !historicalSessions.isEmpty else { return nil }

        let currentElapsed = Date().timeIntervalSince(currentSession.startTime)
        guard currentElapsed > 0 else { return nil }

        let currentProgress = completedExercises.count
        let currentRate = Double(currentProgress) / (currentElapsed / 60.0)

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

            for i in 0..<(order.count - 1) {
                let currentExerciseId = order[i]
                let nextExerciseId = order[i + 1]

                let currentExerciseSets = sets.filter { $0.exercise?.id == currentExerciseId }
                    .sorted { $0.startTime < $1.startTime }
                let nextExerciseSets = sets.filter { $0.exercise?.id == nextExerciseId }
                    .sorted { $0.startTime < $1.startTime }

                if let lastSet = currentExerciseSets.last,
                   let firstSet = nextExerciseSets.first {
                    let transitionStart = lastSet.endTime ?? lastSet.startTime
                    let transitionTime = firstSet.startTime.timeIntervalSince(transitionStart)

                    if transitionTime >= Constants.Transition.minReasonableTime && transitionTime <= Constants.Transition.maxReasonableTime {
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
