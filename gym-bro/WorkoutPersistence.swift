//
//  WorkoutPersistence.swift
//  gym-bro
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.gym-bro", category: "WorkoutPersistence")

struct WorkoutPersistence {

    static func createSession(for split: Split, at index: Int, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(
            startTime: Date.now,
            split: split,
            splitName: split.name,
            splitId: split.id
        )
        context.insert(session)
        save(context: context)
        return session
    }

    static func logWeightSet(
        weight: Double,
        reps: Int,
        exercise: Exercise,
        session: WorkoutSession,
        previousSet: WorkoutSet?,
        wasTimerActive: Bool,
        in context: ModelContext
    ) {
        let now = Date.now

        if let previous = previousSet {
            previous.restDuration = now.timeIntervalSince(previous.startTime)
            previous.restTimerUsed = wasTimerActive
        }

        let workoutSet = WorkoutSet(
            startTime: now,
            weight: weight,
            reps: reps,
            exercise: exercise,
            session: session,
            endTime: now
        )

        context.insert(workoutSet)

        if session.sets == nil { session.sets = [] }
        session.sets?.append(workoutSet)

        if exercise.history == nil { exercise.history = [] }
        exercise.history?.append(workoutSet)

        if let minReps = exercise.minReps,
           let targetWeight = exercise.targetWeight,
           reps >= minReps && weight > targetWeight {
            exercise.targetWeight = weight
        }

        save(context: context)
    }

    static func logDurationSet(
        minutes: Int,
        exercise: Exercise,
        session: WorkoutSession,
        previousSet: WorkoutSet?,
        wasTimerActive: Bool,
        in context: ModelContext
    ) {
        let now = Date.now

        if let previous = previousSet {
            previous.restDuration = now.timeIntervalSince(previous.startTime)
            previous.restTimerUsed = wasTimerActive
        }

        let workoutSet = WorkoutSet(
            startTime: now,
            duration: minutes,
            exercise: exercise,
            session: session,
            endTime: now
        )

        context.insert(workoutSet)

        if session.sets == nil { session.sets = [] }
        session.sets?.append(workoutSet)

        if exercise.history == nil { exercise.history = [] }
        exercise.history?.append(workoutSet)

        save(context: context)
    }

    static func endSession(
        _ session: WorkoutSession,
        split: Split?,
        in context: ModelContext
    ) {
        session.endTime = Date.now

        if let sets = session.sets {
            var orderSeen: [UUID] = []
            let sortedSets = sets.sorted { $0.startTime < $1.startTime }

            for set in sortedSets {
                if let exerciseId = set.exercise?.id, !orderSeen.contains(exerciseId) {
                    orderSeen.append(exerciseId)
                }
            }

            session.actualExerciseOrder = orderSeen.isEmpty ? nil : orderSeen
        }

        if let split = split,
           let allExercises = split.exercises,
           let performedOrder = session.actualExerciseOrder {
            let performedIds = Set(performedOrder)
            let skippedIds = allExercises
                .map { $0.id }
                .filter { !performedIds.contains($0) }

            session.skippedExerciseIds = skippedIds.isEmpty ? nil : skippedIds
        }

        save(context: context)
    }

    private static func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save model context: \(error.localizedDescription)")
        }
    }
}
