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
        recomputeDerivedState(for: session, split: split, in: context)
        save(context: context)
    }

    // Recomputes actualExerciseOrder and skippedExerciseIds from the session's
    // current sets. Callers are responsible for saving.
    static func recomputeDerivedState(for session: WorkoutSession, split: Split? = nil, in context: ModelContext) {
        var orderSeen: [UUID] = []
        let sortedSets = (session.sets ?? []).sorted { $0.startTime < $1.startTime }

        for set in sortedSets {
            if let exerciseId = set.exercise?.id, !orderSeen.contains(exerciseId) {
                orderSeen.append(exerciseId)
            }
        }

        session.actualExerciseOrder = orderSeen.isEmpty ? nil : orderSeen

        let resolvedSplit = split ?? session.split
        if let resolvedSplit = resolvedSplit,
           let allExercises = resolvedSplit.exercises {
            let performedIds = Set(orderSeen)
            let skippedIds = allExercises
                .map { $0.id }
                .filter { !performedIds.contains($0) }

            session.skippedExerciseIds = skippedIds.isEmpty ? nil : skippedIds
        }
    }

    static func updateSet(_ set: WorkoutSet, weight: Double?, reps: Int?, duration: Int?, startTime: Date, in context: ModelContext) {
        let session = set.session

        // Preserve the set's duration (startTime -> endTime delta) across the edit.
        set.endTime = set.endTime.map { startTime.addingTimeInterval($0.timeIntervalSince(set.startTime)) }
        set.startTime = startTime

        set.weight = weight
        set.reps = reps
        set.duration = duration

        // Deliberately leaves restDuration, restTimerUsed, location profiles, and
        // exercise.targetWeight untouched: these are live-measured telemetry / live
        // coaching side effects that retroactive edits must not fabricate.

        if let session = session {
            recomputeDerivedState(for: session, in: context)
        }
        save(context: context)
    }

    static func deleteSet(_ set: WorkoutSet, in context: ModelContext) {
        let session = set.session
        let exercise = set.exercise

        context.delete(set)

        // context.delete does not synchronously prune the set from the
        // session.sets / exercise.history relationships (that only happens on
        // the next save/processing pass), so recomputeDerivedState would
        // otherwise see the deleted set and keep the exercise marked as
        // performed. Prune it eagerly. Compare on object identity rather than
        // WorkoutSet.id (which is not @Attribute(.unique)).
        session?.sets?.removeAll { $0 === set }
        exercise?.history?.removeAll { $0 === set }

        if let session = session {
            recomputeDerivedState(for: session, in: context)
        }
        save(context: context)
    }

    @discardableResult
    static func addSet(exercise: Exercise, session: WorkoutSession, weight: Double?, reps: Int?, duration: Int?, startTime: Date, in context: ModelContext) -> WorkoutSet {
        let workoutSet = WorkoutSet(
            startTime: startTime,
            weight: weight,
            reps: reps,
            duration: duration,
            exercise: exercise,
            session: session,
            endTime: startTime
        )

        context.insert(workoutSet)

        if session.sets == nil { session.sets = [] }
        session.sets?.append(workoutSet)

        if exercise.history == nil { exercise.history = [] }
        exercise.history?.append(workoutSet)

        recomputeDerivedState(for: session, in: context)
        save(context: context)

        return workoutSet
    }

    static func removeExercise(_ exercise: Exercise, from session: WorkoutSession, in context: ModelContext) {
        let toDelete = (session.sets ?? []).filter { $0.exercise?.id == exercise.id }
        for set in toDelete {
            context.delete(set)
        }

        // Prune the deleted sets eagerly so recomputeDerivedState sees the
        // post-removal set list (see deleteSet for the underlying reason).
        // Match on persistentModelID rather than WorkoutSet.id (not unique).
        let removedIDs = Set(toDelete.map { $0.persistentModelID })
        session.sets?.removeAll { removedIDs.contains($0.persistentModelID) }
        exercise.history?.removeAll { removedIDs.contains($0.persistentModelID) }

        recomputeDerivedState(for: session, in: context)
        save(context: context)
    }

    static func updateSessionTimes(_ session: WorkoutSession, startTime: Date, endTime: Date?, in context: ModelContext) {
        guard endTime == nil || startTime < endTime! else { return }

        session.startTime = startTime
        session.endTime = endTime

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
