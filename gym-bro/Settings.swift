//
//  Settings.swift
//  gym-bro
//
//  Created by Moritz Gößl on 13.01.26.
//

import Foundation
import Combine

class Settings: ObservableObject {
    @Published var defaultRestTimerDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(defaultRestTimerDuration, forKey: "defaultRestTimerDuration")
        }
    }

    @Published var defaultTransitionTimerDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(defaultTransitionTimerDuration, forKey: "defaultTransitionTimerDuration")
        }
    }

    static let shared = Settings()

    init() {
        self.defaultRestTimerDuration = UserDefaults.standard.object(forKey: "defaultRestTimerDuration") as? TimeInterval ?? 120
        self.defaultTransitionTimerDuration = UserDefaults.standard.object(forKey: "defaultTransitionTimerDuration") as? TimeInterval ?? 60
    }
}
