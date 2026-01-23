//
//  WorkoutSession.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation
import SwiftData

@Model
class WorkoutSession: Identifiable {
    var id: UUID

    var startTime: Date
    var endTime: Date?
    var location: String?

    // Enhanced tracking for improved predictions
    var skippedExerciseIds: [UUID]?       // IDs of exercises that were skipped
    var actualExerciseOrder: [UUID]?      // Order exercises were actually performed

    @Relationship(deleteRule: .cascade)
    var split: Split?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        location: String? = nil,
        split: Split? = nil,
        skippedExerciseIds: [UUID]? = nil,
        actualExerciseOrder: [UUID]? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.split = split
        self.skippedExerciseIds = skippedExerciseIds
        self.actualExerciseOrder = actualExerciseOrder
    }

    // Computed properties for temporal analysis
    var timeOfDay: Int {
        Calendar.current.component(.hour, from: startTime)
    }

    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: startTime)
    }

    var daysSincePreviousWorkout: Int? {
        // This will be calculated by the predictor using historical data
        return nil
    }
}
