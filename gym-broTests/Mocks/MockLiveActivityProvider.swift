//
//  MockLiveActivityProvider.swift
//  gym-broTests
//

import Foundation
@testable import gym_bro

@MainActor
class MockLiveActivityProvider: LiveActivityProviding {
    var startWorkoutCalls: [(exerciseName: String, setNumber: Int)] = []
    var endWorkoutCallCount = 0
    var updateToIdleCalls: [(exerciseName: String, setNumber: Int)] = []
    var startRestTimerCalls: [(exerciseName: String, setNumber: Int, duration: TimeInterval)] = []
    var startTransitionTimerCalls: [(exerciseName: String, target: String?, notes: String?, duration: TimeInterval)] = []
    var restTimerExpiredCalls: [(exerciseName: String, setNumber: Int)] = []
    var transitionTimerExpiredCalls: [(exerciseName: String, target: String?, notes: String?)] = []
    var acknowledgeExpiredCalls: [(exerciseName: String, setNumber: Int)] = []
    var requestNotificationCallCount = 0

    func startWorkoutActivity(exerciseName: String, setNumber: Int) {
        startWorkoutCalls.append((exerciseName, setNumber))
    }

    func endWorkoutActivity() {
        endWorkoutCallCount += 1
    }

    func updateToIdle(exerciseName: String, setNumber: Int) {
        updateToIdleCalls.append((exerciseName, setNumber))
    }

    func startRestTimer(currentExerciseName: String, currentSetNumber: Int, duration: TimeInterval) {
        startRestTimerCalls.append((currentExerciseName, currentSetNumber, duration))
    }

    func startTransitionTimer(nextExerciseName: String, target: String?, notes: String?, duration: TimeInterval) {
        startTransitionTimerCalls.append((nextExerciseName, target, notes, duration))
    }

    func setRestTimerExpired(currentExerciseName: String, currentSetNumber: Int) {
        restTimerExpiredCalls.append((currentExerciseName, currentSetNumber))
    }

    func setTransitionTimerExpired(nextExerciseName: String, target: String?, notes: String?) {
        transitionTimerExpiredCalls.append((nextExerciseName, target, notes))
    }

    func acknowledgeExpiredTimer(exerciseName: String, setNumber: Int) {
        acknowledgeExpiredCalls.append((exerciseName, setNumber))
    }

    func requestNotificationAuthorization() {
        requestNotificationCallCount += 1
    }
}
