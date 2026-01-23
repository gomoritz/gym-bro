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

    @Relationship(deleteRule: .nullify)
    var split: Split?

    // Store split info for display when split is deleted (avoids crash on orphaned references)
    var splitName: String?
    var splitId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        location: String? = nil,
        split: Split? = nil,
        skippedExerciseIds: [UUID]? = nil,
        actualExerciseOrder: [UUID]? = nil,
        splitName: String? = nil,
        splitId: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.split = split
        self.skippedExerciseIds = skippedExerciseIds
        self.actualExerciseOrder = actualExerciseOrder
        self.splitName = splitName ?? split?.name
        self.splitId = splitId ?? split?.id
    }

    // Safe accessor for split name - does NOT access split relationship to avoid crash
    var displaySplitName: String {
        splitName ?? "Unknown Split"
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
