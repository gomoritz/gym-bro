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
    var id: UUID = UUID()

    var startTime: Date = Date.now
    var endTime: Date?

    // Enhanced tracking for improved predictions
    var skippedExerciseIds: [UUID]?       // IDs of exercises that were skipped
    var actualExerciseOrder: [UUID]?      // Order exercises were actually performed

    @Relationship(deleteRule: .nullify)
    var split: Split?

    // Store split info for display when split is deleted (avoids crash on orphaned references)
    var splitName: String?
    var splitId: UUID?

    var gymLocation: GymLocation?
    var gymLocationName: String?
    var gymLocationId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        split: Split? = nil,
        skippedExerciseIds: [UUID]? = nil,
        actualExerciseOrder: [UUID]? = nil,
        splitName: String? = nil,
        splitId: UUID? = nil,
        gymLocation: GymLocation? = nil,
        gymLocationName: String? = nil,
        gymLocationId: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.split = split
        self.skippedExerciseIds = skippedExerciseIds
        self.actualExerciseOrder = actualExerciseOrder
        self.splitName = splitName ?? split?.name
        self.splitId = splitId ?? split?.id
        self.gymLocation = gymLocation
        self.gymLocationName = gymLocationName ?? gymLocation?.name
        self.gymLocationId = gymLocationId ?? gymLocation?.id
    }

    // Safe accessor for split name - does NOT access split relationship to avoid crash
    var displaySplitName: String {
        splitName ?? "Unknown Split"
    }

    var displayLocationName: String? {
        gymLocationName
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
