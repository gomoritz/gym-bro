//
//  ExerciseLocationProfile.swift
//  gym-bro
//

import Foundation
import SwiftData

@Model
class ExerciseLocationProfile: Identifiable {
    var id: UUID
    var targetWeight: Double?
    var notes: String?
    var lastWeightIncrease: Date?
    var previousWeight: Double?
    var increaseAcknowledged: Bool

    var exercise: Exercise?
    var location: GymLocation?

    init(
        id: UUID = UUID(),
        targetWeight: Double? = nil,
        notes: String? = nil,
        lastWeightIncrease: Date? = nil,
        previousWeight: Double? = nil,
        increaseAcknowledged: Bool = true,
        exercise: Exercise? = nil,
        location: GymLocation? = nil
    ) {
        self.id = id
        self.targetWeight = targetWeight
        self.notes = notes
        self.lastWeightIncrease = lastWeightIncrease
        self.previousWeight = previousWeight
        self.increaseAcknowledged = increaseAcknowledged
        self.exercise = exercise
        self.location = location
    }
}
