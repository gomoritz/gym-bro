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

    var exercise: Exercise?
    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        startTime: Date = Date.now,
        weight: Double? = nil,
        reps: Int? = nil,
        exercise: Exercise? = nil,
        session: WorkoutSession? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.weight = weight
        self.reps = reps
        self.exercise = exercise
        self.session = session
    }
}
