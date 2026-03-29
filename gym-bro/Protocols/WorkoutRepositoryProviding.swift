//
//  WorkoutRepositoryProviding.swift
//  gym-bro
//

import Foundation
import SwiftData

protocol WorkoutRepositoryProviding {
    func createSession(for split: Split, at index: Int, location: GymLocation?, in context: ModelContext) -> WorkoutSession
    func logWeightSet(weight: Double, reps: Int, exercise: Exercise, session: WorkoutSession, previousSet: WorkoutSet?, wasTimerActive: Bool, in context: ModelContext)
    func logDurationSet(minutes: Int, exercise: Exercise, session: WorkoutSession, previousSet: WorkoutSet?, wasTimerActive: Bool, in context: ModelContext)
    func endSession(_ session: WorkoutSession, split: Split?, in context: ModelContext)
    func findOrCreateProfile(exercise: Exercise, location: GymLocation, in context: ModelContext) -> ExerciseLocationProfile
    func save(context: ModelContext)
}
