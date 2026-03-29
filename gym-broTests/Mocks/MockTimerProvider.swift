//
//  MockTimerProvider.swift
//  gym-broTests
//

import Foundation
@testable import gym_bro

class MockTimerProvider: TimerProviding {
    var isActive: Bool = false
    var duration: TimeInterval = 0
    var timeRemaining: TimeInterval = 0
    var isExpired: Bool = false
    var onTimerTick: (() -> Void)?
    var onTimerExpired: (() -> Void)?

    var startCallCount = 0
    var stopCallCount = 0
    var acknowledgeExpiryCallCount = 0
    var lastStartDuration: TimeInterval?

    func start(duration: TimeInterval) {
        startCallCount += 1
        lastStartDuration = duration
        self.duration = duration
        self.timeRemaining = duration
        self.isActive = true
        self.isExpired = false
    }

    func stop() {
        stopCallCount += 1
        isActive = false
        isExpired = false
    }

    func acknowledgeExpiry() {
        acknowledgeExpiryCallCount += 1
        isExpired = false
    }

    func simulateExpiry() {
        isActive = false
        isExpired = true
        timeRemaining = 0
        onTimerExpired?()
    }
}
