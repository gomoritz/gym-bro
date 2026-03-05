//
//  GymLocation.swift
//  gym-bro
//

import Foundation
import SwiftData

@Model
class GymLocation: Identifiable {
    var id: UUID
    var name: String
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLocationProfile.location)
    var exerciseProfiles: [ExerciseLocationProfile]?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.gymLocation)
    var sessions: [WorkoutSession]?

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}
