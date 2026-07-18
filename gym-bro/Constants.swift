//
//  Constants.swift
//  gym-bro
//

import Foundation

enum Constants {
    enum Timer {
        static let restDurationRange: ClosedRange<Double> = 30...600
        static let restDurationStep: Double = 15
        static let defaultRestDuration: TimeInterval = 120

        static let transitionDurationRange: ClosedRange<Double> = 15...300
        static let transitionDurationStep: Double = 15
        static let defaultTransitionDuration: TimeInterval = 60

        static let tickInterval: TimeInterval = 0.1
    }

    enum Transition {
        static let minReasonableTime: TimeInterval = 10
        static let maxReasonableTime: TimeInterval = 300
    }

    enum Prediction {
        static let highConfidenceThreshold = 10
        static let mediumConfidenceThreshold = 3
        static let lowConfidenceThreshold = 1
        static let timeOfDayWindowHours = 3
        static let recencyDecayFactor = 0.9
        static let longRestDaysThreshold = 4
        static let longRestDurationMultiplier = 1.1
        static let shortRestDaysThreshold = 1
        static let shortRestDurationMultiplier = 0.95
        static let singleSetFallbackDuration: TimeInterval = 30
        static let skipProbabilityDampeningFactor = 0.5
    }

    enum Progression {
        static let trendSessionWindow = 3     // sessions considered for e1RM trend
        static let e1rmMarginRatio = 0.025    // 2.5% over implied e1RM before Trigger B fires
        static let weightStep = 1.0           // rounding step for suggested weight
    }
}
