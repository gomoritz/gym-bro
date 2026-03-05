//
//  WorkoutPersistence.swift
//  gym-bro
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.gym-bro", category: "WorkoutPersistence")

struct WorkoutPersistence {

    static func createSession(for split: Split, at index: Int, location: GymLocation? = nil, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(
            startTime: Date.now,
            split: split,
            splitName: split.name,
            splitId: split.id,
            gymLocation: location,
            gymLocationName: location?.name,
            gymLocationId: location?.id
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

        // Location-aware profile updates
        if let location = session.gymLocation {
            let profile = findOrCreateProfile(exercise: exercise, location: location, in: context)

            if profile.targetWeight == nil {
                profile.targetWeight = weight
            } else if let minReps = exercise.minReps,
                      let profileWeight = profile.targetWeight,
                      reps >= minReps && weight > profileWeight {
                profile.previousWeight = profileWeight
                profile.targetWeight = weight
                profile.lastWeightIncrease = Date.now
                profile.increaseAcknowledged = true
                markOtherProfilesUnacknowledged(for: exercise, excludingLocation: location)
            }
        }

        save(context: context)
    }

    static func findOrCreateProfile(exercise: Exercise, location: GymLocation, in context: ModelContext) -> ExerciseLocationProfile {
        if let existing = exercise.profile(for: location) {
            return existing
        }

        let profile = ExerciseLocationProfile(
            exercise: exercise,
            location: location
        )
        context.insert(profile)

        if exercise.locationProfiles == nil { exercise.locationProfiles = [] }
        exercise.locationProfiles?.append(profile)

        if location.exerciseProfiles == nil { location.exerciseProfiles = [] }
        location.exerciseProfiles?.append(profile)

        return profile
    }

    private static func markOtherProfilesUnacknowledged(for exercise: Exercise, excludingLocation location: GymLocation) {
        guard let profiles = exercise.locationProfiles else { return }
        for profile in profiles where profile.location?.id != location.id {
            profile.increaseAcknowledged = false
        }
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
