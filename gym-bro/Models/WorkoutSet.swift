//
//  WorkoutSet.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation
import SwiftData

@Model
class WorkoutSet: Identifiable {
    var id: UUID = UUID()

    var startTime: Date = Date.now
    var weight: Double?
    var reps: Int?
    var duration: Int? // Duration in minutes for exercises without targets

    // Enhanced tracking data for improved predictions
    var endTime: Date?                    // When set was completed
    var restDuration: TimeInterval?       // Actual rest taken after this set
    var restTimerUsed: Bool?              // Whether user used the rest timer

    // Optional difficulty tracking
    var rpe: Int?                         // Rate of perceived exertion (1-10)
    var targetRepsAttempted: Int?         // Target reps for this set
    var wasFailure: Bool?                 // Whether set ended in failure

    var exercise: Exercise?

    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        startTime: Date = Date.now,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: Int? = nil,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil,
        endTime: Date? = nil,
        restDuration: TimeInterval? = nil,
        restTimerUsed: Bool? = nil,
        rpe: Int? = nil,
        targetRepsAttempted: Int? = nil,
        wasFailure: Bool? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.exercise = exercise
        self.session = session
        self.endTime = endTime
        self.restDuration = restDuration
        self.restTimerUsed = restTimerUsed
        self.rpe = rpe
        self.targetRepsAttempted = targetRepsAttempted
        self.wasFailure = wasFailure
    }

    // Computed property for set duration
    var setDuration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }
}
