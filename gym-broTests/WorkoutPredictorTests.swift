//
//  WorkoutPredictorTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class WorkoutPredictorTests: XCTestCase {

    // MARK: - Helpers

    private func makeExercise(name: String = "Bench Press") -> Exercise {
        Exercise(name: name, targetWeight: 80, targetSets: 3, minReps: 8, maxReps: 12)
    }

    // MARK: - Confidence

    func testConfidence_noHistory() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])
        let session = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        session.sets = []

        let predictor = WorkoutPredictor(
            currentSession: session, split: split, allSessions: [session],
            completedExercises: [], currentExercise: ex, remainingExercises: []
        )

        let prediction = predictor.generatePrediction()
        XCTAssertEqual(prediction.confidence, .none)
    }

    func testConfidence_lowWithOneSession() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])

        let historical = WorkoutSession(
            startTime: Date().addingTimeInterval(-86400),
            endTime: Date().addingTimeInterval(-82800),
            splitId: split.id
        )
        let now = Date().addingTimeInterval(-86400)
        historical.sets = [
            WorkoutSet(startTime: now, weight: 80, reps: 10, exercise: ex, session: historical, endTime: now.addingTimeInterval(30)),
            WorkoutSet(startTime: now.addingTimeInterval(120), weight: 80, reps: 8, exercise: ex, session: historical, endTime: now.addingTimeInterval(150)),
        ]

        let current = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        current.sets = []

        let predictor = WorkoutPredictor(
            currentSession: current, split: split, allSessions: [current, historical],
            completedExercises: [], currentExercise: ex, remainingExercises: []
        )

        let prediction = predictor.generatePrediction()
        XCTAssertEqual(prediction.confidence, .low)
    }

    // MARK: - Prediction generation

    func testPrediction_noRemainingExercises() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])
        let session = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        session.sets = []

        let predictor = WorkoutPredictor(
            currentSession: session, split: split, allSessions: [session],
            completedExercises: [], currentExercise: ex, remainingExercises: []
        )

        let prediction = predictor.generatePrediction()
        XCTAssertNotNil(prediction)
        XCTAssertNotNil(prediction.exercisePredictions[ex.id])
    }

    func testPrediction_exercisePredictionsPopulated() {
        let ex1 = makeExercise(name: "Bench")
        let ex2 = makeExercise(name: "Squat")
        let split = Split(name: "Push", exercises: [ex1, ex2])
        let session = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        session.sets = []

        let predictor = WorkoutPredictor(
            currentSession: session, split: split, allSessions: [session],
            completedExercises: [], currentExercise: ex1, remainingExercises: [ex2]
        )

        let prediction = predictor.generatePrediction()
        XCTAssertNotNil(prediction.exercisePredictions[ex1.id])
        XCTAssertNotNil(prediction.exercisePredictions[ex2.id])
    }

    // MARK: - Pace info

    func testPaceInfo_noHistory() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])
        let session = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        session.sets = []

        let predictor = WorkoutPredictor(
            currentSession: session, split: split, allSessions: [session],
            completedExercises: [], currentExercise: ex, remainingExercises: []
        )

        let prediction = predictor.generatePrediction()
        XCTAssertNil(prediction.paceInfo)
    }

    // MARK: - Historical comparison

    func testHistoricalComparison_noHistory() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])
        let session = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        session.sets = []

        let predictor = WorkoutPredictor(
            currentSession: session, split: split, allSessions: [session],
            completedExercises: [], currentExercise: ex, remainingExercises: []
        )

        let prediction = predictor.generatePrediction()
        XCTAssertNil(prediction.historicalComparison)
    }

    func testHistoricalComparison_withHistory() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])

        let historical = WorkoutSession(
            startTime: Date().addingTimeInterval(-86400),
            endTime: Date().addingTimeInterval(-82800),
            splitId: split.id
        )
        historical.sets = [
            WorkoutSet(startTime: Date().addingTimeInterval(-86400), weight: 80, reps: 10, exercise: ex, session: historical),
        ]

        let current = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        current.sets = []

        let predictor = WorkoutPredictor(
            currentSession: current, split: split, allSessions: [current, historical],
            completedExercises: [], currentExercise: ex, remainingExercises: []
        )

        let prediction = predictor.generatePrediction()
        XCTAssertNotNil(prediction.historicalComparison)
        XCTAssertEqual(prediction.historicalComparison?.sessionCount, 1)
    }

    // MARK: - Skip probability

    func testSkipProbability_neverSkipped() {
        let ex = makeExercise()
        let split = Split(name: "Push", exercises: [ex])

        var sessions: [WorkoutSession] = []
        for i in 1...3 {
            let s = WorkoutSession(
                startTime: Date().addingTimeInterval(Double(-i * 86400)),
                endTime: Date().addingTimeInterval(Double(-i * 86400 + 3600)),
                splitId: split.id
            )
            s.sets = [WorkoutSet(weight: 80, reps: 10, exercise: ex, session: s)]
            s.skippedExerciseIds = nil
            sessions.append(s)
        }

        let current = WorkoutSession(startTime: Date(), split: split, splitId: split.id)
        current.sets = []
        sessions.append(current)

        let predictor = WorkoutPredictor(
            currentSession: current, split: split, allSessions: sessions,
            completedExercises: [], currentExercise: nil, remainingExercises: [ex]
        )

        let prediction = predictor.generatePrediction()
        let exPred = prediction.exercisePredictions[ex.id]
        XCTAssertEqual(exPred?.skipProbability, 0.0)
    }
}
