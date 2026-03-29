//
//  InputDefaultsServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class InputDefaultsServiceTests: XCTestCase {

    // MARK: - Nil exercise

    func testDefaults_nilExercise() {
        let result = InputDefaultsService.defaults(for: nil, lastSet: nil, location: nil)
        XCTAssertEqual(result.weight, "")
        XCTAssertEqual(result.reps, "")
        XCTAssertEqual(result.duration, "")
    }

    // MARK: - Target exercise with last set

    func testDefaults_targetExercise_withLastSet() {
        let exercise = Exercise(name: "Bench", targetWeight: 80, targetSets: 3, minReps: 8, maxReps: 12)
        let lastSet = WorkoutSet(weight: 82.5, reps: 10, exercise: exercise)

        let result = InputDefaultsService.defaults(for: exercise, lastSet: lastSet, location: nil)
        XCTAssertEqual(result.weight, "82.5")
        XCTAssertEqual(result.reps, "10")
        XCTAssertEqual(result.duration, "")
    }

    // MARK: - Target exercise without last set

    func testDefaults_targetExercise_noLastSet() {
        let exercise = Exercise(name: "Bench", targetWeight: 80, targetSets: 3, minReps: 8, maxReps: 12)

        let result = InputDefaultsService.defaults(for: exercise, lastSet: nil, location: nil)
        XCTAssertEqual(result.weight, "80.0")
        XCTAssertEqual(result.reps, "12") // maxReps
        XCTAssertEqual(result.duration, "")
    }

    func testDefaults_targetExercise_noLastSet_onlyMinReps() {
        let exercise = Exercise(name: "Bench", targetWeight: 80, targetSets: 3, minReps: 8, maxReps: nil)

        let result = InputDefaultsService.defaults(for: exercise, lastSet: nil, location: nil)
        XCTAssertEqual(result.reps, "8")
    }

    func testDefaults_targetExercise_noLastSet_noReps() {
        let exercise = Exercise(name: "Bench", targetWeight: 80, targetSets: 3, minReps: nil, maxReps: nil)

        let result = InputDefaultsService.defaults(for: exercise, lastSet: nil, location: nil)
        XCTAssertEqual(result.reps, "")
    }

    func testDefaults_targetExercise_noLastSet_noWeight() {
        let exercise = Exercise(name: "Bench", targetWeight: nil, targetSets: 3, minReps: 8, maxReps: 12)

        let result = InputDefaultsService.defaults(for: exercise, lastSet: nil, location: nil)
        XCTAssertEqual(result.weight, "")
    }

    // MARK: - Duration exercise

    func testDefaults_durationExercise_withLastSet() {
        let exercise = Exercise(name: "Plank")
        let lastSet = WorkoutSet(duration: 3, exercise: exercise)

        let result = InputDefaultsService.defaults(for: exercise, lastSet: lastSet, location: nil)
        XCTAssertEqual(result.weight, "")
        XCTAssertEqual(result.reps, "")
        XCTAssertEqual(result.duration, "3")
    }

    func testDefaults_durationExercise_noLastSet() {
        let exercise = Exercise(name: "Plank")

        let result = InputDefaultsService.defaults(for: exercise, lastSet: nil, location: nil)
        XCTAssertEqual(result.weight, "")
        XCTAssertEqual(result.reps, "")
        XCTAssertEqual(result.duration, "")
    }
}
