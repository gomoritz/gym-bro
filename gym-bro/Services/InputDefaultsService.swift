//
//  InputDefaultsService.swift
//  gym-bro
//

import Foundation

struct InputDefaults {
    let weight: String
    let reps: String
    let duration: String
}

struct InputDefaultsService {
    static func defaults(
        for exercise: Exercise?,
        lastSet: WorkoutSet?,
        location: GymLocation?
    ) -> InputDefaults {
        guard let exercise else {
            return InputDefaults(weight: "", reps: "", duration: "")
        }

        if exercise.hasTarget {
            let weight: String
            let reps: String

            if let lastSet {
                weight = String(format: "%.1f", lastSet.weight ?? 0)
                reps = "\(lastSet.reps ?? 0)"
            } else {
                if let effectiveWeight = exercise.effectiveTargetWeight(for: location) {
                    weight = String(format: "%.1f", effectiveWeight)
                } else {
                    weight = ""
                }

                if let maxReps = exercise.maxReps {
                    reps = "\(maxReps)"
                } else if let minReps = exercise.minReps {
                    reps = "\(minReps)"
                } else {
                    reps = ""
                }
            }

            return InputDefaults(weight: weight, reps: reps, duration: "")
        } else {
            let duration: String
            if let lastSet, let lastDuration = lastSet.duration {
                duration = "\(lastDuration)"
            } else {
                duration = ""
            }
            return InputDefaults(weight: "", reps: "", duration: duration)
        }
    }
}
