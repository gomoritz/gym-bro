//
//  WeightRatioEngineTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class WeightRatioEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeExercise() -> Exercise {
        Exercise(name: "Bench Press", targetWeight: 80, targetSets: 3, minReps: 8, maxReps: 12)
    }

    private func makeLocation(name: String) -> GymLocation {
        GymLocation(name: name)
    }

    // MARK: - No historical data

    func testSuggestWeight_noData() {
        let exercise = makeExercise()
        let source = makeLocation(name: "Gym A")
        let target = makeLocation(name: "Gym B")

        let result = WeightRatioEngine.suggestWeight(
            for: exercise, from: source, to: target,
            newSourceWeight: 80, allSessions: []
        )

        XCTAssertEqual(result.suggestedWeight, 80) // 1:1 fallback, rounded to 2.5
        XCTAssertEqual(result.confidence, .none)
        XCTAssertEqual(result.dataPoints, 0)
        XCTAssertNil(result.ratio)
    }

    // MARK: - Rounding

    func testSuggestWeight_roundsToNearest2_5() {
        let exercise = makeExercise()
        let source = makeLocation(name: "Gym A")
        let target = makeLocation(name: "Gym B")

        // 83.7 should round to 82.5 or 85.0
        let result = WeightRatioEngine.suggestWeight(
            for: exercise, from: source, to: target,
            newSourceWeight: 83.7, allSessions: []
        )

        // 83.7 / 2.5 = 33.48, rounded = 33, * 2.5 = 82.5
        XCTAssertEqual(result.suggestedWeight, 82.5)
    }

    func testSuggestWeight_exactMultiple() {
        let exercise = makeExercise()
        let source = makeLocation(name: "Gym A")
        let target = makeLocation(name: "Gym B")

        let result = WeightRatioEngine.suggestWeight(
            for: exercise, from: source, to: target,
            newSourceWeight: 80.0, allSessions: []
        )

        XCTAssertEqual(result.suggestedWeight, 80.0)
    }

    // MARK: - With historical data

    func testSuggestWeight_singlePair() {
        let exercise = makeExercise()
        let source = makeLocation(name: "Gym A")
        let target = makeLocation(name: "Gym B")
        let now = Date()

        // Create sessions at each location
        let sourceSession = WorkoutSession(startTime: now.addingTimeInterval(-86400), gymLocation: source, gymLocationId: source.id)
        sourceSession.sets = [WorkoutSet(weight: 80, reps: 10, exercise: exercise, session: sourceSession)]

        let targetSession = WorkoutSession(startTime: now.addingTimeInterval(-43200), gymLocation: target, gymLocationId: target.id)
        targetSession.sets = [WorkoutSet(weight: 75, reps: 10, exercise: exercise, session: targetSession)]

        let result = WeightRatioEngine.suggestWeight(
            for: exercise, from: source, to: target,
            newSourceWeight: 85,
            allSessions: [sourceSession, targetSession]
        )

        XCTAssertEqual(result.confidence, .low) // 1 data point
        XCTAssertEqual(result.dataPoints, 1)
        XCTAssertNotNil(result.ratio)
        // ratio = 75/80 = 0.9375, suggested = 85 * 0.9375 = 79.6875, rounded = 80.0
        XCTAssertEqual(result.suggestedWeight, 80.0)
    }

    // MARK: - Confidence levels

    func testConfidence_singlePoint() {
        // Already tested above — .low for 1 data point
    }

    func testConfidence_fiveOrMore() {
        let exercise = makeExercise()
        let source = makeLocation(name: "Gym A")
        let target = makeLocation(name: "Gym B")
        let now = Date()

        var sessions: [WorkoutSession] = []
        for i in 0..<5 {
            let sourceSession = WorkoutSession(
                startTime: now.addingTimeInterval(Double(-i * 86400 * 2)),
                gymLocation: source, gymLocationId: source.id
            )
            sourceSession.sets = [WorkoutSet(weight: 80, reps: 10, exercise: exercise, session: sourceSession)]

            let targetSession = WorkoutSession(
                startTime: now.addingTimeInterval(Double(-i * 86400 * 2 - 43200)),
                gymLocation: target, gymLocationId: target.id
            )
            targetSession.sets = [WorkoutSet(weight: 75, reps: 10, exercise: exercise, session: targetSession)]

            sessions.append(contentsOf: [sourceSession, targetSession])
        }

        let result = WeightRatioEngine.suggestWeight(
            for: exercise, from: source, to: target,
            newSourceWeight: 85,
            allSessions: sessions
        )

        XCTAssertEqual(result.confidence, .high)
        XCTAssertGreaterThanOrEqual(result.dataPoints, 5)
    }
}
