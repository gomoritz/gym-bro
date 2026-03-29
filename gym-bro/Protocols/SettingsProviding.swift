//
//  SettingsProviding.swift
//  gym-bro
//

import Foundation

protocol SettingsProviding {
    var defaultRestTimerDuration: TimeInterval { get }
    var defaultTransitionTimerDuration: TimeInterval { get }
}

protocol UserDefaultsProviding {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: UserDefaultsProviding {}
