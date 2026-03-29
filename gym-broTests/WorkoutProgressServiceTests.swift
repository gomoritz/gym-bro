//
//  WorkoutProgressServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class WorkoutProgressServiceTests: XCTestCase {

    // MARK: - calculateWorkoutProgress

    func testProgress_nilSplit() {
        let result = WorkoutProgressService.calculateWorkoutProgress(
            split: nil, currentExercise: nil, currentSetNumber: 1, completedExercises: nil
        )
        XCTAssertNil(result)
    }

    func testProgress_emptyExercises() {
        let split = Split(name: "Push", exercises: [])
        let result = WorkoutProgressService.calculateWorkoutProgress(
            split: split, currentExercise: nil, currentSetNumber: 1, completedExercises: nil
        )
        XCTAssertNil(result)
    }

    func testProgress_oneOfThreeCompleted() {
        let ex1 = Exercise(name: "Bench", targetSets: 3)
        let ex2 = Exercise(name: "Squat", targetSets: 3)
        let ex3 = Exercise(name: "Row", targetSets: 3)
        let split = Split(name: "Push", exercises: [ex1, ex2, ex3])

        let result = WorkoutProgressService.calculateWorkoutProgress(
            split: split, currentExercise: ex2, currentSetNumber: 1, completedExercises: [ex1]
        )
        // 1/3 completed + 0/3 current set progress
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 1.0 / 3.0, accuracy: 0.01)
    }

    func testProgress_withCurrentSetProgress() {
        let ex1 = Exercise(name: "Bench", targetSets: 3)
        let ex2 = Exercise(name: "Squat", targetSets: 4)
        let split = Split(name: "Push", exercises: [ex1, ex2])

        let result = WorkoutProgressService.calculateWorkoutProgress(
            split: split, currentExercise: ex2, currentSetNumber: 3, completedExercises: [ex1]
        )
        // 1/2 + (2/4)/2 = 0.5 + 0.25 = 0.75
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.75, accuracy: 0.01)
    }

    func testProgress_cappedAtOne() {
        let ex1 = Exercise(name: "Bench", targetSets: 1)
        let split = Split(name: "Push", exercises: [ex1])

        let result = WorkoutProgressService.calculateWorkoutProgress(
            split: split, currentExercise: ex1, currentSetNumber: 5, completedExercises: []
        )
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(result!, 1.0)
    }

    // MARK: - getCompletedExercises

    func testCompletedExercises_nilSession() {
        let result = WorkoutProgressService.getCompletedExercises(session: nil, split: nil, currentExerciseId: nil)
        XCTAssertNil(result)
    }

    func testCompletedExercises_withData() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")
        let ex3 = Exercise(name: "Row")
        let split = Split(name: "Push", exercises: [ex1, ex2, ex3])
        let session = WorkoutSession(startTime: Date())
        let now = Date()

        session.sets = [
            WorkoutSet(startTime: now, weight: 80, reps: 10, exercise: ex1, session: session),
            WorkoutSet(startTime: now.addingTimeInterval(60), weight: 100, reps: 5, exercise: ex2, session: session),
            WorkoutSet(startTime: now.addingTimeInterval(120), weight: 60, reps: 12, exercise: ex3, session: session),
        ]

        // ex3 is current
        let result = WorkoutProgressService.getCompletedExercises(session: session, split: split, currentExerciseId: ex3.id)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?[0].name, "Bench")
        XCTAssertEqual(result?[1].name, "Squat")
    }

    // MARK: - exerciseDuration

    func testExerciseDuration_singleSet() {
        let exercise = Exercise(name: "Bench")
        let sets = [WorkoutSet(startTime: Date(), weight: 80, reps: 10, exercise: exercise)]
        XCTAssertNil(WorkoutProgressService.exerciseDuration(for: exercise, sets: sets))
    }

    func testExerciseDuration_multipleSets() {
        let exercise = Exercise(name: "Bench")
        let now = Date()
        let sets = [
            WorkoutSet(startTime: now, weight: 80, reps: 10, exercise: exercise),
            WorkoutSet(startTime: now.addingTimeInterval(180), weight: 80, reps: 8, exercise: exercise),
        ]
        let duration = WorkoutProgressService.exerciseDuration(for: exercise, sets: sets)
        XCTAssertEqual(duration, 180)
    }

    func testExerciseDuration_nilSets() {
        let exercise = Exercise(name: "Bench")
        XCTAssertNil(WorkoutProgressService.exerciseDuration(for: exercise, sets: nil))
    }
}
