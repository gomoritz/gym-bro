//
//  FormatServiceTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

final class FormatServiceTests: XCTestCase {

    // MARK: - formatDuration

    func testFormatDuration_zeroSeconds() {
        XCTAssertEqual(FormatService.formatDuration(0), "< 1m")
    }

    func testFormatDuration_lessThanOneMinute() {
        XCTAssertEqual(FormatService.formatDuration(30), "< 1m")
    }

    func testFormatDuration_exactlyOneMinute() {
        XCTAssertEqual(FormatService.formatDuration(60), "1m")
    }

    func testFormatDuration_multipleMinutes() {
        XCTAssertEqual(FormatService.formatDuration(300), "5m")
    }

    func testFormatDuration_oneHour() {
        XCTAssertEqual(FormatService.formatDuration(3600), "1h 0m")
    }

    func testFormatDuration_oneHourThirtyMinutes() {
        XCTAssertEqual(FormatService.formatDuration(5400), "1h 30m")
    }

    func testFormatDuration_twoHours() {
        XCTAssertEqual(FormatService.formatDuration(7200), "2h 0m")
    }

    func testFormatDuration_45Minutes() {
        XCTAssertEqual(FormatService.formatDuration(2700), "45m")
    }

    // MARK: - formatTimeRemaining

    func testFormatTimeRemaining_zeroSeconds() {
        XCTAssertEqual(FormatService.formatTimeRemaining(0), "Almost done!")
    }

    func testFormatTimeRemaining_lessThanOneMinute() {
        XCTAssertEqual(FormatService.formatTimeRemaining(30), "Almost done!")
    }

    func testFormatTimeRemaining_fiveMinutes() {
        XCTAssertEqual(FormatService.formatTimeRemaining(300), "5m left")
    }

    func testFormatTimeRemaining_oneHourTenMinutes() {
        XCTAssertEqual(FormatService.formatTimeRemaining(4200), "1h 10m left")
    }

    // MARK: - timeAgoString

    func testTimeAgo_justNow() {
        let now = Date()
        let date = now.addingTimeInterval(-10)
        XCTAssertEqual(FormatService.timeAgoString(from: date, relativeTo: now), "just now")
    }

    func testTimeAgo_minutesAgo() {
        let now = Date()
        let date = now.addingTimeInterval(-180) // 3 minutes
        XCTAssertEqual(FormatService.timeAgoString(from: date, relativeTo: now), "3m ago")
    }

    func testTimeAgo_hoursAgo() {
        let now = Date()
        let date = now.addingTimeInterval(-7200) // 2 hours
        XCTAssertEqual(FormatService.timeAgoString(from: date, relativeTo: now), "2h ago")
    }

    func testTimeAgo_exactlyOneMinute() {
        let now = Date()
        let date = now.addingTimeInterval(-60)
        XCTAssertEqual(FormatService.timeAgoString(from: date, relativeTo: now), "1m ago")
    }

    func testTimeAgo_exactlyOneHour() {
        let now = Date()
        let date = now.addingTimeInterval(-3600)
        XCTAssertEqual(FormatService.timeAgoString(from: date, relativeTo: now), "1h ago")
    }
}
