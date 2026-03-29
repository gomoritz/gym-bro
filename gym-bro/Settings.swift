//
//  Settings.swift
//  gym-bro
//
//  Created by Moritz Goessl on 13.01.26.
//

import Foundation
import SwiftUI

@Observable
class Settings: SettingsProviding {
    private let store: UserDefaultsProviding

    var defaultRestTimerDuration: TimeInterval {
        didSet {
            store.set(defaultRestTimerDuration, forKey: "defaultRestTimerDuration")
        }
    }

    var defaultTransitionTimerDuration: TimeInterval {
        didSet {
            store.set(defaultTransitionTimerDuration, forKey: "defaultTransitionTimerDuration")
        }
    }

    init(store: UserDefaultsProviding = UserDefaults.standard) {
        self.store = store
        self.defaultRestTimerDuration = store.object(forKey: "defaultRestTimerDuration") as? TimeInterval ?? Constants.Timer.defaultRestDuration
        self.defaultTransitionTimerDuration = store.object(forKey: "defaultTransitionTimerDuration") as? TimeInterval ?? Constants.Timer.defaultTransitionDuration
    }
}
