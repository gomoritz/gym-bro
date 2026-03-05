//
//  WeightRatioEngine.swift
//  gym-bro
//

import Foundation
import SwiftData

enum SuggestionConfidence {
    case none
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .none: "No data"
        case .low: "Low confidence"
        case .medium: "Medium"
        case .high: "Reliable"
        }
    }
}

struct WeightSuggestion {
    let suggestedWeight: Double
    let confidence: SuggestionConfidence
    let ratio: Double?
    let dataPoints: Int
}

struct WeightRatioEngine {

    static func suggestWeight(
        for exercise: Exercise,
        from sourceLocation: GymLocation,
        to targetLocation: GymLocation,
        newSourceWeight: Double,
        allSessions: [WorkoutSession]
    ) -> WeightSuggestion {

        // Gather max weight per session at each location for this exercise
        var sourceWeights: [(date: Date, weight: Double)] = []
        var targetWeights: [(date: Date, weight: Double)] = []

        for session in allSessions {
            guard let sets = session.sets else { continue }
            let exerciseSets = sets.filter { $0.exercise?.id == exercise.id && $0.weight != nil }
            guard !exerciseSets.isEmpty else { continue }

            let maxWeight = exerciseSets.compactMap { $0.weight }.max() ?? 0
            guard maxWeight > 0 else { continue }

            if session.gymLocationId == sourceLocation.id {
                sourceWeights.append((session.startTime, maxWeight))
            } else if session.gymLocationId == targetLocation.id {
                targetWeights.append((session.startTime, maxWeight))
            }
        }

        // Find time-close pairs (within 14 days)
        let maxGap: TimeInterval = 14 * 24 * 3600
        var pairs: [(sourceWeight: Double, targetWeight: Double, recency: Date)] = []

        for s in sourceWeights {
            for t in targetWeights {
                if abs(s.date.timeIntervalSince(t.date)) <= maxGap {
                    let moreRecent = max(s.date, t.date)
                    pairs.append((s.weight, t.weight, moreRecent))
                }
            }
        }

        let dataPoints = pairs.count

        guard dataPoints > 0 else {
            // Fallback: 1:1 ratio
            return WeightSuggestion(
                suggestedWeight: roundToStep(newSourceWeight),
                confidence: .none,
                ratio: nil,
                dataPoints: 0
            )
        }

        // Weighted average ratio with recency decay
        let now = Date.now
        let decayFactor: Double = 30 * 24 * 3600 // 30-day half-life

        var weightedRatioSum: Double = 0
        var weightSum: Double = 0

        for pair in pairs {
            let age = now.timeIntervalSince(pair.recency)
            let w = exp(-age / decayFactor)
            let ratio = pair.targetWeight / pair.sourceWeight
            weightedRatioSum += ratio * w
            weightSum += w
        }

        let avgRatio = weightedRatioSum / weightSum
        let suggested = roundToStep(newSourceWeight * avgRatio)

        let confidence: SuggestionConfidence
        switch dataPoints {
        case 1: confidence = .low
        case 2...4: confidence = .medium
        default: confidence = .high
        }

        return WeightSuggestion(
            suggestedWeight: suggested,
            confidence: confidence,
            ratio: avgRatio,
            dataPoints: dataPoints
        )
    }

    private static func roundToStep(_ weight: Double, step: Double = 2.5) -> Double {
        (weight / step).rounded() * step
    }
}
