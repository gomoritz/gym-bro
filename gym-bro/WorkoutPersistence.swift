//
//  WorkoutPersistence.swift
//  gym-bro
//

import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.gym-bro", category: "WorkoutPersistence")

class WorkoutRepository: WorkoutRepositoryProviding {

    func createSession(for split: Split, at index: Int, location: GymLocation? = nil, in context: ModelContext) -> WorkoutSession {
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

    func logWeightSet(
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

    func findOrCreateProfile(exercise: Exercise, location: GymLocation, in context: ModelContext) -> ExerciseLocationProfile {
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

    private func markOtherProfilesUnacknowledged(for exercise: Exercise, excludingLocation location: GymLocation) {
        guard let profiles = exercise.locationProfiles else { return }
        for profile in profiles where profile.location?.id != location.id {
            profile.increaseAcknowledged = false
        }
    }

    func logDurationSet(
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

    func endSession(
        _ session: WorkoutSession,
        split: Split?,
        in context: ModelContext
    ) {
        session.endTime = Date.now

        if let sets = session.sets {
            session.actualExerciseOrder = SessionCompletionService.computeExerciseOrder(from: sets)
        }

        if let split = split,
           let allExercises = split.exercises,
           let performedOrder = session.actualExerciseOrder {
            session.skippedExerciseIds = SessionCompletionService.computeSkippedExercises(
                allExercises: allExercises,
                performedOrder: performedOrder
            )
        }

        save(context: context)
    }

    func save(context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save model context: \(error.localizedDescription)")
        }
    }
}

// MARK: - Static convenience for backward compatibility
enum WorkoutPersistence {
    private static let shared = WorkoutRepository()

    static func createSession(for split: Split, at index: Int, location: GymLocation? = nil, in context: ModelContext) -> WorkoutSession {
        shared.createSession(for: split, at: index, location: location, in: context)
    }

    static func logWeightSet(weight: Double, reps: Int, exercise: Exercise, session: WorkoutSession, previousSet: WorkoutSet?, wasTimerActive: Bool, in context: ModelContext) {
        shared.logWeightSet(weight: weight, reps: reps, exercise: exercise, session: session, previousSet: previousSet, wasTimerActive: wasTimerActive, in: context)
    }

    static func logDurationSet(minutes: Int, exercise: Exercise, session: WorkoutSession, previousSet: WorkoutSet?, wasTimerActive: Bool, in context: ModelContext) {
        shared.logDurationSet(minutes: minutes, exercise: exercise, session: session, previousSet: previousSet, wasTimerActive: wasTimerActive, in: context)
    }

    static func endSession(_ session: WorkoutSession, split: Split?, in context: ModelContext) {
        shared.endSession(session, split: split, in: context)
    }

    static func findOrCreateProfile(exercise: Exercise, location: GymLocation, in context: ModelContext) -> ExerciseLocationProfile {
        shared.findOrCreateProfile(exercise: exercise, location: location, in: context)
    }
}
