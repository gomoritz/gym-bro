//
//  WorkoutProgressService.swift
//  gym-bro
//

import Foundation

struct WorkoutProgressService {
    static func calculateWorkoutProgress(
        split: Split?,
        currentExercise: Exercise?,
        currentSetNumber: Int,
        completedExercises: [Exercise]?
    ) -> Double? {
        guard let split,
              let exercises = split.exercises,
              !exercises.isEmpty else {
            return nil
        }

        let completed = completedExercises?.count ?? 0
        let total = exercises.count

        guard total > 0 else { return nil }

        var progress = Double(completed) / Double(total)

        if let currentEx = currentExercise,
           let targetSets = currentEx.targetSets,
           targetSets > 0 {
            let currentSetProgress = Double(currentSetNumber - 1) / Double(targetSets)
            progress += currentSetProgress / Double(total)
        }

        return min(progress, 1.0)
    }

    static func getCompletedExercises(
        session: WorkoutSession?,
        split: Split?,
        currentExerciseId: UUID?
    ) -> [Exercise]? {
        guard let session,
              let sets = session.sets,
              let split,
              let exercises = split.exercises else {
            return nil
        }

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

    static func exerciseDuration(for exercise: Exercise, sets: [WorkoutSet]?) -> TimeInterval? {
        guard let sets, sets.count >= 2 else {
            return nil
        }

        let firstSet = sets.first!
        let lastSet = sets.last!
        return lastSet.startTime.timeIntervalSince(firstSet.startTime)
    }

    static func getSetsForExercise(_ exercise: Exercise, in session: WorkoutSession?) -> [WorkoutSet]? {
        guard let session,
              let sets = session.sets else {
            return nil
        }

        let exerciseSets = sets.filter { $0.exercise?.id == exercise.id }
            .sorted { $0.startTime < $1.startTime }
        return exerciseSets.isEmpty ? nil : exerciseSets
    }
}
