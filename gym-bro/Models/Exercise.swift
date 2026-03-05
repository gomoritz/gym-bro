//
//  Exercise.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation
import SwiftData

@Model
class Exercise: Identifiable {
    var id: UUID

    var name: String

    var targetSets: Int?
    var minReps: Int?
    var maxReps: Int?

    var restTimerDurationOverride: TimeInterval?

    var category: ExerciseCategory?

    var splits: [Split]?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLocationProfile.exercise)
    var locationProfiles: [ExerciseLocationProfile]?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var history: [WorkoutSet]?

    init(
        id: UUID = UUID(),
        name: String,
        targetSets: Int? = nil,
        minReps: Int? = nil,
        maxReps: Int? = nil,
        restTimerDurationOverride: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.targetSets = targetSets
        self.minReps = minReps
        self.maxReps = maxReps
        self.restTimerDurationOverride = restTimerDurationOverride
    }

    var hasTargetSets: Bool { targetSets != nil }
    var hasTargetReps: Bool { minReps != nil && maxReps != nil }
    var hasTarget: Bool { hasTargetSets && hasTargetReps }

    var splitNames: String? {
        splits != nil && splits!.count > 0
            ? splits!.map { $0.name }.joined(separator: ", ") : nil
    }
}
