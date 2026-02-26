//
//  Exercise+TargetString.swift
//  gym-bro
//

import Foundation

extension Exercise {
    var targetString: String? {
        guard hasTarget else { return nil }
        var parts: [String] = []
        if let sets = targetSets {
            parts.append("\(sets) sets")
        }
        if let min = minReps, let max = maxReps {
            parts.append("\(min)-\(max) reps")
        }
        if let weight = targetWeight {
            parts.append("@ \(String(format: "%.1f", weight))kg")
        }
        return parts.joined(separator: " ")
    }
}
