//
//  Settings.swift
//  gym-bro
//
//  Created by Moritz Goessl on 13.01.26.
//

import Foundation
import SwiftUI

@Observable
class Settings {
    var defaultRestTimerDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(defaultRestTimerDuration, forKey: "defaultRestTimerDuration")
        }
    }

    var defaultTransitionTimerDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(defaultTransitionTimerDuration, forKey: "defaultTransitionTimerDuration")
        }
    }

    init() {
        self.defaultRestTimerDuration = UserDefaults.standard.object(forKey: "defaultRestTimerDuration") as? TimeInterval ?? Constants.Timer.defaultRestDuration
        self.defaultTransitionTimerDuration = UserDefaults.standard.object(forKey: "defaultTransitionTimerDuration") as? TimeInterval ?? Constants.Timer.defaultTransitionDuration
    }
}
