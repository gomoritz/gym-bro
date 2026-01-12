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
    var id: UUID

    var startTime: Date
    var weight: Double?
    var reps: Int?
    var duration: Int? // Duration in minutes for exercises without targets

    var exercise: Exercise?
    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        startTime: Date = Date.now,
        weight: Double? = nil,
        reps: Int? = nil,
        duration: Int? = nil,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.exercise = exercise
        self.session = session
    }
}
