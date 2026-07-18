//
//  ProgressionEngine.swift
//  gym-bro
//

import Foundation
import SwiftData

enum ProgressionTrigger {
    case repMaxReached(sessionDate: Date, completedSets: Int, targetSets: Int, reps: Int, weight: Double)
    case e1rmTrend(bestRecentE1RM: Double, impliedE1RM: Double, sessionsConsidered: Int)

    var title: String {
        switch self {
        case .repMaxReached: return "Rep max reached"
        case .e1rmTrend: return "Strength trend"
        }
    }

    var detail: String {
        switch self {
        case let .repMaxReached(_, completedSets, _, reps, weight):
            return "\(completedSets)×\(reps) @ \(ProgressionEngine.formatWeight(weight)) last session"
        case let .e1rmTrend(best, implied, _):
            return "Best e1RM \(ProgressionEngine.formatWeight(best)) vs \(ProgressionEngine.formatWeight(implied)) implied by target"
        }
    }

    var iconName: String {
        switch self {
        case .repMaxReached: return "checkmark.circle.fill"
        case .e1rmTrend: return "chart.line.uptrend.xyaxis"
        }
    }
}

struct ProgressionBasis {
    let gymScoped: Bool
    let locationName: String?
    let currentTargetWeight: Double
    let impliedE1RM: Double
    let bestRecentE1RM: Double
    let sessionsConsidered: Int
    let mostRecentSessionDate: Date?
}

struct ProgressionSuggestion {
    let triggers: [ProgressionTrigger]
    let suggestedWeight: Double
    let basis: ProgressionBasis

    var suggestsIncrease: Bool { !triggers.isEmpty }
}

enum ProgressionEngine {

    static func e1RM(weight: Double, reps: Int) -> Double {
        weight * (1.0 + Double(reps) / 30.0)
    }

    static func weightForE1RM(_ e1rm: Double, reps: Int) -> Double {
        e1rm / (1.0 + Double(reps) / 30.0)
    }

    static func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f kg", weight)
        }
        return String(format: "%.1f kg", weight)
    }

    private struct SessionAggregate {
        let date: Date
        let sets: [WorkoutSet]
        let topE1RM: Double
    }

    static func evaluate(exercise: Exercise, at location: GymLocation?) -> ProgressionSuggestion? {
        guard exercise.hasTarget,
              let minReps = exercise.minReps,
              let maxReps = exercise.maxReps,
              let targetSets = exercise.targetSets,
              let target = exercise.effectiveTargetWeight(for: location)
        else { return nil }

        let history = exercise.history ?? []
        let baseUsable = history.filter { set in
            guard let w = set.weight, w > 0,
                  let r = set.reps, r > 0,
                  set.session != nil
            else { return false }
            return true
        }
        guard !baseUsable.isEmpty else { return nil }

        let scoped: [WorkoutSet]
        if let location {
            scoped = baseUsable.filter { $0.session?.gymLocationId == location.id }
        } else {
            scoped = baseUsable
        }

        let impliedE1RM = e1RM(weight: target, reps: maxReps)

        guard !scoped.isEmpty else {
            let basis = ProgressionBasis(
                gymScoped: true,
                locationName: location?.name,
                currentTargetWeight: target,
                impliedE1RM: impliedE1RM,
                bestRecentE1RM: 0,
                sessionsConsidered: 0,
                mostRecentSessionDate: nil
            )
            return ProgressionSuggestion(triggers: [], suggestedWeight: target, basis: basis)
        }

        let grouped = Dictionary(grouping: scoped) { $0.session!.id }
        let sessions = grouped.map { _, sets -> SessionAggregate in
            let date = sets.map { $0.startTime }.min() ?? Date.now
            let topE1RM = sets.map { e1RM(weight: $0.weight ?? 0, reps: $0.reps ?? 0) }.max() ?? 0
            return SessionAggregate(date: date, sets: sets, topE1RM: topE1RM)
        }.sorted { $0.date < $1.date }

        let window = Constants.Progression.trendSessionWindow
        let recent = sessions.suffix(window)
        let bestRecentE1RM = recent.map { $0.topE1RM }.max() ?? 0
        let sessionsConsidered = recent.count

        var triggers: [ProgressionTrigger] = []

        // Trigger A: last session filled all target sets at the top of the rep range at (or above) target.
        if let lastSession = sessions.last {
            let orderedSets = lastSession.sets.sorted { $0.startTime < $1.startTime }
            if orderedSets.count >= targetSets {
                let firstSets = orderedSets.prefix(targetSets)
                let allAtMax = firstSets.allSatisfy { set in
                    guard let r = set.reps, let w = set.weight else { return false }
                    return r >= maxReps && w >= target - 0.01
                }
                if allAtMax {
                    let repWeight = firstSets.compactMap { $0.weight }.min() ?? target
                    triggers.append(.repMaxReached(
                        sessionDate: lastSession.date,
                        completedSets: targetSets,
                        targetSets: targetSets,
                        reps: maxReps,
                        weight: repWeight
                    ))
                }
            }
        }

        // Trigger B: recent best e1RM has pulled clear of what the current target implies.
        if bestRecentE1RM >= impliedE1RM * (1 + Constants.Progression.e1rmMarginRatio) {
            triggers.append(.e1rmTrend(
                bestRecentE1RM: bestRecentE1RM,
                impliedE1RM: impliedE1RM,
                sessionsConsidered: sessionsConsidered
            ))
        }

        var suggestedWeight = WeightRatioEngine.roundToStep(
            weightForE1RM(max(bestRecentE1RM, impliedE1RM), reps: minReps),
            step: Constants.Progression.weightStep
        )
        // With narrow rep ranges the e1RM-derived weight can round back to the
        // current target; a suggested increase must always land above it.
        if !triggers.isEmpty && suggestedWeight <= target {
            suggestedWeight = WeightRatioEngine.roundToStep(
                target + Constants.Progression.weightStep,
                step: Constants.Progression.weightStep
            )
        }

        let basis = ProgressionBasis(
            gymScoped: location != nil,
            locationName: location?.name,
            currentTargetWeight: target,
            impliedE1RM: impliedE1RM,
            bestRecentE1RM: bestRecentE1RM,
            sessionsConsidered: sessionsConsidered,
            mostRecentSessionDate: sessions.last?.date
        )

        return ProgressionSuggestion(triggers: triggers, suggestedWeight: suggestedWeight, basis: basis)
    }
}
