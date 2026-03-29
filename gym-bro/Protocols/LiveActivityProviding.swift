//
//  LiveActivityProviding.swift
//  gym-bro
//

import Foundation

@MainActor
protocol LiveActivityProviding {
    func startWorkoutActivity(exerciseName: String, setNumber: Int)
    func endWorkoutActivity()
    func updateToIdle(exerciseName: String, setNumber: Int)
    func startRestTimer(currentExerciseName: String, currentSetNumber: Int, duration: TimeInterval)
    func startTransitionTimer(nextExerciseName: String, target: String?, notes: String?, duration: TimeInterval)
    func setRestTimerExpired(currentExerciseName: String, currentSetNumber: Int)
    func setTransitionTimerExpired(nextExerciseName: String, target: String?, notes: String?)
    func acknowledgeExpiredTimer(exerciseName: String, setNumber: Int)
    func requestNotificationAuthorization()
}
