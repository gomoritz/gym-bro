//
//  MockWorkoutRepository.swift
//  gym-broTests
//

import Foundation
import SwiftData
@testable import gym_bro

class MockWorkoutRepository: WorkoutRepositoryProviding {
    var createSessionCallCount = 0
    var logWeightSetCallCount = 0
    var logDurationSetCallCount = 0
    var endSessionCallCount = 0
    var findOrCreateProfileCallCount = 0
    var saveCallCount = 0

    var lastLoggedWeight: Double?
    var lastLoggedReps: Int?
    var lastLoggedMinutes: Int?
    var lastEndedSession: WorkoutSession?

    // Store for returning from createSession
    var sessionToReturn: WorkoutSession?

    func createSession(for split: Split, at index: Int, location: GymLocation?, in context: ModelContext) -> WorkoutSession {
        createSessionCallCount += 1
        if let session = sessionToReturn {
            return session
        }
        return WorkoutSession(startTime: Date(), split: split, splitName: split.name, splitId: split.id)
    }

    func logWeightSet(weight: Double, reps: Int, exercise: Exercise, session: WorkoutSession, previousSet: WorkoutSet?, wasTimerActive: Bool, in context: ModelContext) {
        logWeightSetCallCount += 1
        lastLoggedWeight = weight
        lastLoggedReps = reps
    }

    func logDurationSet(minutes: Int, exercise: Exercise, session: WorkoutSession, previousSet: WorkoutSet?, wasTimerActive: Bool, in context: ModelContext) {
        logDurationSetCallCount += 1
        lastLoggedMinutes = minutes
    }

    func endSession(_ session: WorkoutSession, split: Split?, in context: ModelContext) {
        endSessionCallCount += 1
        lastEndedSession = session
    }

    func findOrCreateProfile(exercise: Exercise, location: GymLocation, in context: ModelContext) -> ExerciseLocationProfile {
        findOrCreateProfileCallCount += 1
        return ExerciseLocationProfile(exercise: exercise, location: location)
    }

    func save(context: ModelContext) {
        saveCallCount += 1
    }
}
