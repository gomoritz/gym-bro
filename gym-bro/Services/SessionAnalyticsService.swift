//
//  SessionAnalyticsService.swift
//  gym-bro
//

import Foundation

struct SessionAnalyticsService {

    // MARK: - Data Types

    struct SessionStats {
        let totalMovedWeight: Double
        let totalSets: Int
        let totalReps: Int
        let uniqueExerciseCount: Int
        let averageIntensity: Double?
    }

    struct ExerciseVolume {
        let exercise: Exercise
        let volume: Double
    }

    struct PersonalRecord {
        let exercise: Exercise
        let weight: Double
        let reps: Int
    }

    struct WorkoutComparison {
        let totalWeight: Double
        let totalReps: Int
        let duration: TimeInterval
    }

    // MARK: - Stats

    static func computeStats(for session: WorkoutSession) -> SessionStats {
        let sets = session.sets ?? []

        let totalMovedWeight = sets.reduce(0.0) { total, set in
            if let weight = set.weight, let reps = set.reps {
                return total + (weight * Double(reps))
            }
            return total
        }

        let totalSets = sets.count

        let totalReps = sets.reduce(0) { total, set in
            total + (set.reps ?? 0)
        }

        let uniqueExercises = Set(sets.compactMap { $0.exercise?.id })
        let uniqueExerciseCount = uniqueExercises.count

        let averageIntensity: Double? = totalReps > 0 ? totalMovedWeight / Double(totalReps) : nil

        return SessionStats(
            totalMovedWeight: totalMovedWeight,
            totalSets: totalSets,
            totalReps: totalReps,
            uniqueExerciseCount: uniqueExerciseCount,
            averageIntensity: averageIntensity
        )
    }

    // MARK: - Volume

    static func computeVolumeBreakdown(for session: WorkoutSession) -> [ExerciseVolume] {
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

    static func exerciseVolume(for exercise: Exercise, in session: WorkoutSession) -> Double? {
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

    // MARK: - Personal Records

    static func detectPersonalRecords(session: WorkoutSession, allSessions: [WorkoutSession]) -> [PersonalRecord] {
        guard let sets = session.sets else { return [] }

        var records: [PersonalRecord] = []

        let exerciseGroups = Dictionary(grouping: sets.compactMap { set -> (Exercise, WorkoutSet)? in
            guard let exercise = set.exercise else { return nil }
            return (exercise, set)
        }, by: { $0.0.id })

        for (exerciseId, exerciseSets) in exerciseGroups {
            guard let exercise = exerciseSets.first?.0 else { continue }

            let historicalSets = allSessions
                .filter { $0.id != session.id }
                .flatMap { $0.sets ?? [] }
                .filter { $0.exercise?.id == exerciseId }

            if let sessionMax = exerciseSets
                .compactMap({ set -> (weight: Double, reps: Int)? in
                    guard let weight = set.1.weight, let reps = set.1.reps else { return nil }
                    return (weight, reps)
                })
                .max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) {

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

    // MARK: - Comparison

    static func previousWorkoutComparison(session: WorkoutSession, allSessions: [WorkoutSession]) -> WorkoutComparison? {
        guard let splitId = session.splitId else { return nil }

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

    // MARK: - Insights

    static func generateInsights(
        session: WorkoutSession,
        stats: SessionStats,
        records: [PersonalRecord],
        comparison: WorkoutComparison?
    ) -> [String] {
        var insights: [String] = []

        if let duration = session.endTime?.timeIntervalSince(session.startTime) {
            let minutes = Int(duration / 60)
            if minutes < 30 {
                insights.append("Quick workout - under 30 minutes")
            } else if minutes > 90 {
                insights.append("Extended session - over 90 minutes")
            }
        }

        if stats.totalMovedWeight > 5000 {
            insights.append("High volume workout - moved over 5 tons")
        }

        if stats.uniqueExerciseCount >= 8 {
            insights.append("Great exercise variety with \(stats.uniqueExerciseCount) different movements")
        }

        if !records.isEmpty {
            insights.append("Set \(records.count) personal record\(records.count > 1 ? "s" : "") this workout")
        }

        if let comparison = comparison {
            let weightDiff = ((stats.totalMovedWeight - comparison.totalWeight) / comparison.totalWeight) * 100
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

    // MARK: - Exercise Ordering

    static func getOrderedExercises(for session: WorkoutSession) -> [Exercise]? {
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

    static func getSetsForExercise(_ exercise: Exercise, in session: WorkoutSession) -> [WorkoutSet]? {
        guard let sets = session.sets else { return nil }

        let exerciseSets = sets
            .filter { $0.exercise?.id == exercise.id }
            .sorted { $0.startTime < $1.startTime }

        return exerciseSets.isEmpty ? nil : exerciseSets
    }
}
