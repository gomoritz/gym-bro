//
//  MockSettings.swift
//  gym-broTests
//

import Foundation
@testable import gym_bro

class MockSettings: SettingsProviding {
    var defaultRestTimerDuration: TimeInterval
    var defaultTransitionTimerDuration: TimeInterval

    init(
        restDuration: TimeInterval = Constants.Timer.defaultRestDuration,
        transitionDuration: TimeInterval = Constants.Timer.defaultTransitionDuration
    ) {
        self.defaultRestTimerDuration = restDuration
        self.defaultTransitionTimerDuration = transitionDuration
    }
}
