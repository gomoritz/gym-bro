//
//  SettingsTests.swift
//  gym-broTests
//

import XCTest
@testable import gym_bro

// In-memory UserDefaults replacement for testing
class InMemoryDefaults: UserDefaultsProviding {
    private var storage: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
}

final class SettingsTests: XCTestCase {

    func testInit_defaultValues() {
        let store = InMemoryDefaults()
        let settings = Settings(store: store)

        XCTAssertEqual(settings.defaultRestTimerDuration, Constants.Timer.defaultRestDuration)
        XCTAssertEqual(settings.defaultTransitionTimerDuration, Constants.Timer.defaultTransitionDuration)
    }

    func testInit_loadsStoredValues() {
        let store = InMemoryDefaults()
        store.set(180.0 as TimeInterval, forKey: "defaultRestTimerDuration")
        store.set(90.0 as TimeInterval, forKey: "defaultTransitionTimerDuration")

        let settings = Settings(store: store)

        XCTAssertEqual(settings.defaultRestTimerDuration, 180.0)
        XCTAssertEqual(settings.defaultTransitionTimerDuration, 90.0)
    }

    func testSet_persistsToStore() {
        let store = InMemoryDefaults()
        let settings = Settings(store: store)

        settings.defaultRestTimerDuration = 200.0
        XCTAssertEqual(store.object(forKey: "defaultRestTimerDuration") as? TimeInterval, 200.0)

        settings.defaultTransitionTimerDuration = 45.0
        XCTAssertEqual(store.object(forKey: "defaultTransitionTimerDuration") as? TimeInterval, 45.0)
    }

    func testConformsToSettingsProviding() {
        let store = InMemoryDefaults()
        let settings: SettingsProviding = Settings(store: store)

        XCTAssertEqual(settings.defaultRestTimerDuration, Constants.Timer.defaultRestDuration)
        XCTAssertEqual(settings.defaultTransitionTimerDuration, Constants.Timer.defaultTransitionDuration)
    }
}
