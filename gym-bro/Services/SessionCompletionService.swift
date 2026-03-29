//
//  SessionCompletionService.swift
//  gym-bro
//

import Foundation

struct SessionCompletionService {
    static func computeExerciseOrder(from sets: [WorkoutSet]) -> [UUID]? {
        var orderSeen: [UUID] = []
        let sortedSets = sets.sorted { $0.startTime < $1.startTime }

        for set in sortedSets {
            if let exerciseId = set.exercise?.id, !orderSeen.contains(exerciseId) {
                orderSeen.append(exerciseId)
            }
        }

        return orderSeen.isEmpty ? nil : orderSeen
    }

    static func computeSkippedExercises(allExercises: [Exercise], performedOrder: [UUID]) -> [UUID]? {
        let performedIds = Set(performedOrder)
        let skippedIds = allExercises
            .map { $0.id }
            .filter { !performedIds.contains($0) }

        return skippedIds.isEmpty ? nil : skippedIds
    }
}
