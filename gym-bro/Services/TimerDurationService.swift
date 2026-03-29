//
//  TimerDurationService.swift
//  gym-bro
//

import Foundation

struct TimerDurationService {
    static func resolveRestDuration(
        exercise: Exercise?,
        isTransition: Bool,
        defaultRestDuration: TimeInterval,
        defaultTransitionDuration: TimeInterval
    ) -> TimeInterval {
        if isTransition {
            return defaultTransitionDuration
        }

        if let exercise,
           let override = exercise.restTimerDurationOverride {
            return override
        }

        return defaultRestDuration
    }
}
