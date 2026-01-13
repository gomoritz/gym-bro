//
//  RestTimerActivityAttributes.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import ActivityKit
import Foundation

// MARK: - Timer State

enum TimerState: String, Codable {
    case idle
    case restTimerRunning
    case transitionTimerRunning
    case restTimerExpired
    case transitionTimerExpired
}

// MARK: - Activity Attributes

struct RestTimerActivityAttributes: ActivityAttributes {
    // Empty attributes since content is dynamic throughout the workout
}

// MARK: - Content State

extension RestTimerActivityAttributes {
    struct ContentState: Codable, Hashable {
        // Current state
        var timerState: TimerState
        
        // Timer info
        var endTime: Date?
        var restDuration: TimeInterval?
        
        // Current exercise info
        var exerciseName: String
        var currentSetNumber: Int?
        
        // Next exercise info (for transition timers or idle state showing next set)
        var nextExerciseName: String?
        var nextExerciseTarget: String?
        var nextExerciseNotes: String?
        
        init(
            timerState: TimerState,
            exerciseName: String,
            currentSetNumber: Int? = nil,
            endTime: Date? = nil,
            restDuration: TimeInterval? = nil,
            nextExerciseName: String? = nil,
            nextExerciseTarget: String? = nil,
            nextExerciseNotes: String? = nil
        ) {
            self.timerState = timerState
            self.exerciseName = exerciseName
            self.currentSetNumber = currentSetNumber
            self.endTime = endTime
            self.restDuration = restDuration
            self.nextExerciseName = nextExerciseName
            self.nextExerciseTarget = nextExerciseTarget
            self.nextExerciseNotes = nextExerciseNotes
        }
    }
}
