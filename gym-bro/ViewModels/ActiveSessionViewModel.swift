//
//  ActiveSessionViewModel.swift
//  gym-bro
//

import Foundation

@Observable
class ActiveSessionViewModel {
    var weight: String = ""
    var reps: String = ""
    var duration: String = ""

    func updateInputDefaults(sessionManager: SessionManager) {
        let defaults = InputDefaultsService.defaults(
            for: sessionManager.currentExercise,
            lastSet: sessionManager.lastSetForCurrentExercise,
            location: sessionManager.currentLocation
        )
        weight = defaults.weight
        reps = defaults.reps
        duration = defaults.duration
    }

    var exerciseProgressText: String? {
        return nil // Computed by view with access to sessionManager
    }

    func computeExerciseProgressText(sessionManager: SessionManager) -> String? {
        guard let split = sessionManager.currentSplit,
              let exercises = split.exercises,
              let session = sessionManager.activeSession else { return nil }

        let currentExerciseId = sessionManager.currentExercise?.id
        let completedExerciseIds = Set((session.sets ?? [])
            .compactMap { $0.exercise?.id }
            .filter { $0 != currentExerciseId })

        let completedCount = completedExerciseIds.count
        let currentNumber = completedCount + 1

        return "\(currentNumber)/\(exercises.count)"
    }

    func hasReachedTargetSets(sessionManager: SessionManager) -> Bool {
        guard let exercise = sessionManager.currentExercise,
              let targetSets = exercise.targetSets else {
            return false
        }
        return sessionManager.currentSetNumber >= targetSets
    }

    /// Attempts to parse input and log a set. Returns true if successful.
    func parseAndLogSet(sessionManager: SessionManager) -> Bool {
        guard let exercise = sessionManager.currentExercise else { return false }

        if exercise.hasTarget {
            guard let weightValue = Double(weight),
                  let repsValue = Int(reps),
                  weightValue > 0,
                  repsValue > 0 else {
                return false
            }
            sessionManager.logSet(weight: weightValue, reps: repsValue)
            return true
        } else {
            guard let durationValue = Int(duration),
                  durationValue > 0 else {
                return false
            }
            sessionManager.logDurationSet(minutes: durationValue)
            return true
        }
    }

    /// Attempts to log current input (if valid) then finishes exercise.
    func finishExercise(sessionManager: SessionManager) {
        if let exercise = sessionManager.currentExercise {
            if exercise.hasTarget {
                if let weightValue = Double(weight),
                   let repsValue = Int(reps),
                   weightValue > 0,
                   repsValue > 0 {
                    sessionManager.logSet(weight: weightValue, reps: repsValue)
                }
            } else {
                if let durationValue = Int(duration),
                   durationValue > 0 {
                    sessionManager.logDurationSet(minutes: durationValue)
                }
            }
        }
    }
}
