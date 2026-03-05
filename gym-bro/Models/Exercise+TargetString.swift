//
//  Exercise+TargetString.swift
//  gym-bro
//

import Foundation

extension Exercise {
    var targetString: String? {
        targetString(for: nil)
    }

    func targetString(for location: GymLocation?) -> String? {
        guard hasTarget else { return nil }
        var parts: [String] = []
        if let sets = targetSets {
            parts.append("\(sets) sets")
        }
        if let min = minReps, let max = maxReps {
            parts.append("\(min)-\(max) reps")
        }
        if let weight = effectiveTargetWeight(for: location) {
            parts.append("@ \(String(format: "%.1f", weight))kg")
        }
        return parts.joined(separator: " ")
    }
}
