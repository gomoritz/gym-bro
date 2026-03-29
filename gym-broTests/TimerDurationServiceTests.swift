//
//  TimerDurationServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class TimerDurationServiceTests: XCTestCase {

    func testResolve_transitionMode() {
        let result = TimerDurationService.resolveRestDuration(
            exercise: Exercise(name: "Bench", restTimerDurationOverride: 90),
            isTransition: true,
            defaultRestDuration: 120,
            defaultTransitionDuration: 60
        )
        XCTAssertEqual(result, 60) // Transition takes precedence
    }

    func testResolve_exerciseOverride() {
        let exercise = Exercise(name: "Bench", restTimerDurationOverride: 90)
        let result = TimerDurationService.resolveRestDuration(
            exercise: exercise,
            isTransition: false,
            defaultRestDuration: 120,
            defaultTransitionDuration: 60
        )
        XCTAssertEqual(result, 90)
    }

    func testResolve_defaultRest() {
        let exercise = Exercise(name: "Bench")
        let result = TimerDurationService.resolveRestDuration(
            exercise: exercise,
            isTransition: false,
            defaultRestDuration: 120,
            defaultTransitionDuration: 60
        )
        XCTAssertEqual(result, 120)
    }

    func testResolve_nilExercise() {
        let result = TimerDurationService.resolveRestDuration(
            exercise: nil,
            isTransition: false,
            defaultRestDuration: 120,
            defaultTransitionDuration: 60
        )
        XCTAssertEqual(result, 120)
    }
}
