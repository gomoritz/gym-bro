//
//  RestTimerActivityAttributes.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import ActivityKit
import Foundation

struct RestTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state that changes during the activity
        var endTime: Date
        var remainingSeconds: TimeInterval
        var isExpired: Bool = false
    }
    
    // Static data that doesn't change during the activity
    var exerciseName: String
    var restDuration: TimeInterval
}
