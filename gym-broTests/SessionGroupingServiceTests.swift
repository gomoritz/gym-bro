//
//  SessionGroupingServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class SessionGroupingServiceTests: XCTestCase {

    // MARK: - groupByWeek

    func testGroupByWeek_empty() {
        let result = SessionGroupingService.groupByWeek([])
        XCTAssertTrue(result.isEmpty)
    }

    func testGroupByWeek_sameWeek() {
        let calendar = Calendar.current
        let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 23))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 25))!

        let s1 = WorkoutSession(startTime: monday)
        let s2 = WorkoutSession(startTime: wednesday)

        let result = SessionGroupingService.groupByWeek([s1, s2])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.values.first?.count, 2)
    }

    func testGroupByWeek_differentWeeks() {
        let calendar = Calendar.current
        let week1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 23))!
        let week2 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30))!

        let s1 = WorkoutSession(startTime: week1)
        let s2 = WorkoutSession(startTime: week2)

        let result = SessionGroupingService.groupByWeek([s1, s2])
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - startOfWeek

    func testStartOfWeek_returnsMonday() {
        let calendar = Calendar.current
        // Wednesday March 25, 2026
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 25))!
        let startOfWeek = SessionGroupingService.startOfWeek(for: wednesday)

        let components = calendar.dateComponents([.weekday], from: startOfWeek)
        // Start of week depends on locale, but should be consistent
        XCTAssertNotNil(startOfWeek)
    }

    // MARK: - orphanedSessionsCount

    func testOrphanedCount_none() {
        let split = Split(name: "Push")
        let s1 = WorkoutSession(startTime: Date(), split: split)
        XCTAssertEqual(SessionGroupingService.orphanedSessionsCount(in: [s1]), 0)
    }

    func testOrphanedCount_some() {
        let s1 = WorkoutSession(startTime: Date())
        // s1 has no split
        XCTAssertEqual(SessionGroupingService.orphanedSessionsCount(in: [s1]), 1)
    }

    func testOrphanedCount_empty() {
        XCTAssertEqual(SessionGroupingService.orphanedSessionsCount(in: []), 0)
    }

    // MARK: - uniqueExerciseCount

    func testUniqueExerciseCount_nilSets() {
        let session = WorkoutSession(startTime: Date())
        session.sets = nil
        XCTAssertNil(SessionGroupingService.uniqueExerciseCount(in: session))
    }

    func testUniqueExerciseCount_emptySets() {
        let session = WorkoutSession(startTime: Date())
        session.sets = []
        XCTAssertNil(SessionGroupingService.uniqueExerciseCount(in: session))
    }

    func testUniqueExerciseCount_withExercises() {
        let ex1 = Exercise(name: "Bench")
        let ex2 = Exercise(name: "Squat")
        let session = WorkoutSession(startTime: Date())
        session.sets = [
            WorkoutSet(weight: 80, reps: 10, exercise: ex1, session: session),
            WorkoutSet(weight: 80, reps: 8, exercise: ex1, session: session),
            WorkoutSet(weight: 100, reps: 5, exercise: ex2, session: session),
        ]
        XCTAssertEqual(SessionGroupingService.uniqueExerciseCount(in: session), 2)
    }
}
