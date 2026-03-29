//
//  SessionAnalyticsServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class SessionAnalyticsServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeExercise(name: String = "Bench Press", targetWeight: Double? = 80, targetSets: Int? = 3, minReps: Int? = 8, maxReps: Int? = 12) -> Exercise {
        Exercise(name: name, targetWeight: targetWeight, targetSets: targetSets, minReps: minReps, maxReps: maxReps)
    }

    private func makeSet(weight: Double? = nil, reps: Int? = nil, duration: Int? = nil, exercise: Exercise? = nil, session: WorkoutSession? = nil, startTime: Date = Date()) -> WorkoutSet {
        WorkoutSet(startTime: startTime, weight: weight, reps: reps, duration: duration, exercise: exercise, session: session)
    }

    private func makeSession(startTime: Date = Date(), endTime: Date? = nil, splitId: UUID? = nil) -> WorkoutSession {
        let session = WorkoutSession(startTime: startTime, endTime: endTime, splitId: splitId)
        return session
    }

    // MARK: - computeStats

    func testComputeStats_emptySets() {
        let session = makeSession()
        session.sets = []
        let stats = SessionAnalyticsService.computeStats(for: session)

        XCTAssertEqual(stats.totalMovedWeight, 0)
        XCTAssertEqual(stats.totalSets, 0)
        XCTAssertEqual(stats.totalReps, 0)
        XCTAssertEqual(stats.uniqueExerciseCount, 0)
        XCTAssertNil(stats.averageIntensity)
    }

    func testComputeStats_nilSets() {
        let session = makeSession()
        session.sets = nil
        let stats = SessionAnalyticsService.computeStats(for: session)

        XCTAssertEqual(stats.totalMovedWeight, 0)
        XCTAssertEqual(stats.totalSets, 0)
    }

    func testComputeStats_withWeightSets() {
        let exercise = makeExercise()
        let session = makeSession()
        let set1 = makeSet(weight: 80, reps: 10, exercise: exercise, session: session)
        let set2 = makeSet(weight: 80, reps: 8, exercise: exercise, session: session)
        session.sets = [set1, set2]

        let stats = SessionAnalyticsService.computeStats(for: session)

        XCTAssertEqual(stats.totalMovedWeight, 80 * 10 + 80 * 8) // 1440
        XCTAssertEqual(stats.totalSets, 2)
        XCTAssertEqual(stats.totalReps, 18)
        XCTAssertEqual(stats.uniqueExerciseCount, 1)
        XCTAssertEqual(stats.averageIntensity, 1440.0 / 18.0)
    }

    func testComputeStats_multipleExercises() {
        let ex1 = makeExercise(name: "Bench")
        let ex2 = makeExercise(name: "Squat")
        let session = makeSession()
        let set1 = makeSet(weight: 80, reps: 10, exercise: ex1, session: session)
        let set2 = makeSet(weight: 100, reps: 5, exercise: ex2, session: session)
        session.sets = [set1, set2]

        let stats = SessionAnalyticsService.computeStats(for: session)
        XCTAssertEqual(stats.uniqueExerciseCount, 2)
        XCTAssertEqual(stats.totalMovedWeight, 800 + 500)
    }

    func testComputeStats_durationSetsIgnoredInWeight() {
        let exercise = makeExercise(name: "Plank", targetWeight: nil, targetSets: nil, minReps: nil, maxReps: nil)
        let session = makeSession()
        let set1 = makeSet(duration: 2, exercise: exercise, session: session)
        session.sets = [set1]

        let stats = SessionAnalyticsService.computeStats(for: session)
        XCTAssertEqual(stats.totalMovedWeight, 0)
        XCTAssertEqual(stats.totalSets, 1)
        XCTAssertEqual(stats.totalReps, 0)
    }

    // MARK: - computeVolumeBreakdown

    func testVolumeBreakdown_empty() {
        let session = makeSession()
        session.sets = []
        let breakdown = SessionAnalyticsService.computeVolumeBreakdown(for: session)
        XCTAssertTrue(breakdown.isEmpty)
    }

    func testVolumeBreakdown_sortedDescending() {
        let ex1 = makeExercise(name: "Bench")
        let ex2 = makeExercise(name: "Squat")
        let session = makeSession()
        session.sets = [
            makeSet(weight: 80, reps: 10, exercise: ex1, session: session),
            makeSet(weight: 100, reps: 10, exercise: ex2, session: session),
        ]

        let breakdown = SessionAnalyticsService.computeVolumeBreakdown(for: session)
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown[0].exercise.name, "Squat") // 1000 > 800
        XCTAssertEqual(breakdown[0].volume, 1000)
        XCTAssertEqual(breakdown[1].volume, 800)
    }

    // MARK: - exerciseVolume

    func testExerciseVolume_noSets() {
        let exercise = makeExercise()
        let session = makeSession()
        session.sets = []
        XCTAssertNil(SessionAnalyticsService.exerciseVolume(for: exercise, in: session))
    }

    func testExerciseVolume_withSets() {
        let exercise = makeExercise()
        let session = makeSession()
        session.sets = [
            makeSet(weight: 80, reps: 10, exercise: exercise, session: session),
            makeSet(weight: 80, reps: 8, exercise: exercise, session: session),
        ]
        XCTAssertEqual(SessionAnalyticsService.exerciseVolume(for: exercise, in: session), 1440)
    }

    // MARK: - detectPersonalRecords

    func testDetectPRs_noPreviousHistory() {
        let exercise = makeExercise()
        let session = makeSession()
        session.sets = [makeSet(weight: 80, reps: 10, exercise: exercise, session: session)]

        let records = SessionAnalyticsService.detectPersonalRecords(session: session, allSessions: [session])
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.weight, 80)
        XCTAssertEqual(records.first?.reps, 10)
    }

    func testDetectPRs_notARecord() {
        let exercise = makeExercise()
        let currentSession = makeSession()
        currentSession.sets = [makeSet(weight: 60, reps: 10, exercise: exercise, session: currentSession)]

        let historicalSession = makeSession()
        historicalSession.sets = [makeSet(weight: 80, reps: 10, exercise: exercise, session: historicalSession)]

        let records = SessionAnalyticsService.detectPersonalRecords(
            session: currentSession,
            allSessions: [currentSession, historicalSession]
        )
        XCTAssertTrue(records.isEmpty)
    }

    func testDetectPRs_isARecord() {
        let exercise = makeExercise()
        let currentSession = makeSession()
        currentSession.sets = [makeSet(weight: 90, reps: 10, exercise: exercise, session: currentSession)]

        let historicalSession = makeSession()
        historicalSession.sets = [makeSet(weight: 80, reps: 10, exercise: exercise, session: historicalSession)]

        let records = SessionAnalyticsService.detectPersonalRecords(
            session: currentSession,
            allSessions: [currentSession, historicalSession]
        )
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.weight, 90)
    }

    // MARK: - previousWorkoutComparison

    func testComparison_noPreviousWorkout() {
        let session = makeSession(splitId: UUID())
        let result = SessionAnalyticsService.previousWorkoutComparison(session: session, allSessions: [session])
        XCTAssertNil(result)
    }

    func testComparison_noSplitId() {
        let session = makeSession()
        let result = SessionAnalyticsService.previousWorkoutComparison(session: session, allSessions: [session])
        XCTAssertNil(result)
    }

    func testComparison_withPreviousWorkout() {
        let splitId = UUID()
        let exercise = makeExercise()

        let previous = makeSession(startTime: Date().addingTimeInterval(-86400), endTime: Date().addingTimeInterval(-83400), splitId: splitId)
        previous.sets = [makeSet(weight: 80, reps: 10, exercise: exercise, session: previous)]

        let current = makeSession(startTime: Date(), splitId: splitId)
        current.sets = [makeSet(weight: 85, reps: 10, exercise: exercise, session: current)]

        let comparison = SessionAnalyticsService.previousWorkoutComparison(
            session: current,
            allSessions: [current, previous]
        )
        XCTAssertNotNil(comparison)
        XCTAssertEqual(comparison?.totalWeight, 800)
        XCTAssertEqual(comparison?.totalReps, 10)
    }

    // MARK: - generateInsights

    func testInsights_defaultInsight() {
        let session = makeSession()
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 1000, totalSets: 5, totalReps: 50, uniqueExerciseCount: 3, averageIntensity: 20
        )
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: nil)
        XCTAssertEqual(insights, ["Solid workout - keep up the consistency"])
    }

    func testInsights_quickWorkout() {
        let session = makeSession(startTime: Date(), endTime: Date().addingTimeInterval(1500)) // 25 min
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 1000, totalSets: 5, totalReps: 50, uniqueExerciseCount: 3, averageIntensity: 20
        )
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: nil)
        XCTAssertTrue(insights.contains("Quick workout - under 30 minutes"))
    }

    func testInsights_extendedSession() {
        let session = makeSession(startTime: Date(), endTime: Date().addingTimeInterval(6000)) // 100 min
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 1000, totalSets: 5, totalReps: 50, uniqueExerciseCount: 3, averageIntensity: 20
        )
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: nil)
        XCTAssertTrue(insights.contains("Extended session - over 90 minutes"))
    }

    func testInsights_highVolume() {
        let session = makeSession()
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 6000, totalSets: 20, totalReps: 100, uniqueExerciseCount: 5, averageIntensity: 60
        )
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: nil)
        XCTAssertTrue(insights.contains("High volume workout - moved over 5 tons"))
    }

    func testInsights_exerciseVariety() {
        let session = makeSession()
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 3000, totalSets: 24, totalReps: 100, uniqueExerciseCount: 8, averageIntensity: 30
        )
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: nil)
        XCTAssertTrue(insights.contains("Great exercise variety with 8 different movements"))
    }

    func testInsights_personalRecords() {
        let session = makeSession()
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 1000, totalSets: 5, totalReps: 50, uniqueExerciseCount: 3, averageIntensity: 20
        )
        let record = SessionAnalyticsService.PersonalRecord(exercise: makeExercise(), weight: 100, reps: 10)
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [record], comparison: nil)
        XCTAssertTrue(insights.contains("Set 1 personal record this workout"))
    }

    func testInsights_volumeIncrease() {
        let session = makeSession()
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 1200, totalSets: 5, totalReps: 50, uniqueExerciseCount: 3, averageIntensity: 24
        )
        let comparison = SessionAnalyticsService.WorkoutComparison(totalWeight: 1000, totalReps: 40, duration: 3600)
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: comparison)
        XCTAssertTrue(insights.contains { $0.contains("increased by") })
    }

    func testInsights_volumeDecrease() {
        let session = makeSession()
        let stats = SessionAnalyticsService.SessionStats(
            totalMovedWeight: 800, totalSets: 5, totalReps: 50, uniqueExerciseCount: 3, averageIntensity: 16
        )
        let comparison = SessionAnalyticsService.WorkoutComparison(totalWeight: 1000, totalReps: 60, duration: 3600)
        let insights = SessionAnalyticsService.generateInsights(session: session, stats: stats, records: [], comparison: comparison)
        XCTAssertTrue(insights.contains { $0.contains("decreased by") })
    }

    // MARK: - getOrderedExercises

    func testGetOrderedExercises_empty() {
        let session = makeSession()
        session.sets = []
        XCTAssertNil(SessionAnalyticsService.getOrderedExercises(for: session))
    }

    func testGetOrderedExercises_ordered() {
        let ex1 = makeExercise(name: "Bench")
        let ex2 = makeExercise(name: "Squat")
        let session = makeSession()
        let now = Date()
        session.sets = [
            makeSet(weight: 80, reps: 10, exercise: ex1, session: session, startTime: now),
            makeSet(weight: 80, reps: 10, exercise: ex1, session: session, startTime: now.addingTimeInterval(60)),
            makeSet(weight: 100, reps: 5, exercise: ex2, session: session, startTime: now.addingTimeInterval(120)),
        ]

        let ordered = SessionAnalyticsService.getOrderedExercises(for: session)
        XCTAssertEqual(ordered?.count, 2)
        XCTAssertEqual(ordered?[0].name, "Bench")
        XCTAssertEqual(ordered?[1].name, "Squat")
    }

    // MARK: - getSetsForExercise

    func testGetSetsForExercise_found() {
        let exercise = makeExercise()
        let session = makeSession()
        let now = Date()
        session.sets = [
            makeSet(weight: 80, reps: 10, exercise: exercise, session: session, startTime: now),
            makeSet(weight: 80, reps: 8, exercise: exercise, session: session, startTime: now.addingTimeInterval(60)),
        ]

        let sets = SessionAnalyticsService.getSetsForExercise(exercise, in: session)
        XCTAssertEqual(sets?.count, 2)
    }

    func testGetSetsForExercise_notFound() {
        let exercise = makeExercise()
        let otherExercise = makeExercise(name: "Other")
        let session = makeSession()
        session.sets = [
            makeSet(weight: 80, reps: 10, exercise: otherExercise, session: session),
        ]

        let sets = SessionAnalyticsService.getSetsForExercise(exercise, in: session)
        XCTAssertNil(sets)
    }
}
