//
//  SessionCompletionServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class SessionCompletionServiceTests: XCTestCase {

    // MARK: - computeExerciseOrder

    func testComputeOrder_empty() {
        let result = SessionCompletionService.computeExerciseOrder(from: [])
        XCTAssertNil(result)
    }

    func testComputeOrder_singleExercise() {
        let exercise = Exercise(name: "Bench")
        let now = Date()
        let sets = [
            WorkoutSet(startTime: now, weight: 80, reps: 10, exercise: exercise),
            WorkoutSet(startTime: now.addingTimeInterval(60), weight: 80, reps: 8, exercise: exercise),
        ]

        let result = SessionCompletionService.computeExerciseOrder(from: sets)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first, exercise.id)
    }

    func testComputeOrder_multipleExercises() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")
        let ex3 = Exercise(name: "Row")
        let now = Date()

        let sets = [
            WorkoutSet(startTime: now, weight: 80, reps: 10, exercise: ex1),
            WorkoutSet(startTime: now.addingTimeInterval(60), weight: 80, reps: 8, exercise: ex1),
            WorkoutSet(startTime: now.addingTimeInterval(120), weight: 100, reps: 5, exercise: ex2),
            WorkoutSet(startTime: now.addingTimeInterval(180), weight: 60, reps: 12, exercise: ex3),
        ]

        let result = SessionCompletionService.computeExerciseOrder(from: sets)
        XCTAssertEqual(result?.count, 3)
        XCTAssertEqual(result?[0], ex1.id)
        XCTAssertEqual(result?[1], ex2.id)
        XCTAssertEqual(result?[2], ex3.id)
    }

    func testComputeOrder_interleavedSets() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")
        let now = Date()

        let sets = [
            WorkoutSet(startTime: now, weight: 80, reps: 10, exercise: ex1),
            WorkoutSet(startTime: now.addingTimeInterval(60), weight: 100, reps: 5, exercise: ex2),
            WorkoutSet(startTime: now.addingTimeInterval(120), weight: 80, reps: 8, exercise: ex1),
        ]

        let result = SessionCompletionService.computeExerciseOrder(from: sets)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0], ex1.id) // First seen
        XCTAssertEqual(result?[1], ex2.id)
    }

    // MARK: - computeSkippedExercises

    func testComputeSkipped_noneSkipped() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")

        let result = SessionCompletionService.computeSkippedExercises(
            allExercises: [ex1, ex2],
            performedOrder: [ex1.id, ex2.id]
        )
        XCTAssertNil(result)
    }

    func testComputeSkipped_oneSkipped() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")
        let ex3 = Exercise(name: "Row")

        let result = SessionCompletionService.computeSkippedExercises(
            allExercises: [ex1, ex2, ex3],
            performedOrder: [ex1.id, ex3.id]
        )
        XCTAssertEqual(result, [ex2.id])
    }

    func testComputeSkipped_allSkipped() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")

        let result = SessionCompletionService.computeSkippedExercises(
            allExercises: [ex1, ex2],
            performedOrder: []
        )
        XCTAssertEqual(result?.count, 2)
    }
}
