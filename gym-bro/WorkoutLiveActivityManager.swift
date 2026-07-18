//
//  WorkoutLiveActivityManager.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import ActivityKit
import AudioToolbox
import Foundation
import UIKit
import UserNotifications

@available(iOS 16.1, *)
let activityAuthInfo = ActivityAuthorizationInfo()

@MainActor
class WorkoutLiveActivityManager: NSObject {
    static let shared = WorkoutLiveActivityManager()
    
    private var currentActivity: Activity<RestTimerActivityAttributes>?
    private var isTimerExpired: Bool = false
    
    override private init() {
        super.init()
        
        // Clean up any existing activities from previous sessions
        Task {
            for activity in Activity<RestTimerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    // MARK: - Notifications
    
    func requestNotificationAuthorization() {
        #if DEBUG
        // Suppress the system notification-permission alert during automated UI
        // tests; it would otherwise intercept taps on the app underneath.
        if DebugTestFlags.seedTestData { return }
        #endif
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
            if let error = error {
                print("Notification authorization failed: \(error)")
            }
        }
    }
    
    private func scheduleNotification(for duration: TimeInterval, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: "TimerComplete", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["TimerComplete"])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - Activity Lifecycle
    
    func startWorkoutActivity(exerciseName: String, setNumber: Int) {
        // Check if activities are enabled
        if #available(iOS 16.1, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("⚠️  Live Activities are not enabled on this device")
                return
            }
        }
        
        // End any existing activity first
        endWorkoutActivity()
        
        isTimerExpired = false
        
        print("🎬 Starting live activity for exercise: \(exerciseName), set: \(setNumber)")
        
        let attributes = RestTimerActivityAttributes()
        
        let initialState = RestTimerActivityAttributes.ContentState(
            timerState: .idle,
            exerciseName: exerciseName,
            currentSetNumber: setNumber
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity started successfully")
        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
            print("Error details: \(error)")
        }
    }
    
    func endWorkoutActivity() {
        cancelNotification()
        
        guard let activity = currentActivity else { return }
        
        currentActivity = nil
        isTimerExpired = false
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    
    // MARK: - Idle State Updates
    
    func updateToIdle(exerciseName: String, setNumber: Int) {
        guard let activity = currentActivity else { return }
        
        isTimerExpired = false
        cancelNotification()
        
        let updatedState = RestTimerActivityAttributes.ContentState(
            timerState: .idle,
            exerciseName: exerciseName,
            currentSetNumber: setNumber
        )
        
        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil,
                    relevanceScore: 0
                )
            )
        }
    }
    
    // MARK: - Rest Timer
    
    func startRestTimer(
        currentExerciseName: String,
        currentSetNumber: Int,
        duration: TimeInterval
    ) {
        print("⏱️  Starting rest timer: \(Int(duration))s for set \(currentSetNumber)")
        guard let activity = currentActivity else {
            print("⚠️  No active live activity to update")
            return
        }
        
        isTimerExpired = false
        
        let endTime = Date().addingTimeInterval(duration)
        
        // Schedule notification as backup
        scheduleNotification(
            for: duration,
            title: "Rest Timer Complete",
            body: "Time to get back to \(currentExerciseName)!"
        )
        
        let updatedState = RestTimerActivityAttributes.ContentState(
            timerState: .restTimerRunning,
            exerciseName: currentExerciseName,
            currentSetNumber: currentSetNumber,
            endTime: endTime,
            restDuration: duration
        )
        
        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil,
                    relevanceScore: 50
                )
            )
        }
    }
    
    // MARK: - Transition Timer
    
    func startTransitionTimer(
        nextExerciseName: String,
        target: String?,
        notes: String?,
        duration: TimeInterval
    ) {
        print("🔄 Starting transition timer: \(Int(duration))s to \(nextExerciseName)")
        guard let activity = currentActivity else {
            print("⚠️  No active live activity to update")
            return
        }
        
        isTimerExpired = false
        
        let endTime = Date().addingTimeInterval(duration)
        
        // Schedule notification as backup
        scheduleNotification(
            for: duration,
            title: "Transition Complete",
            body: "Get ready for \(nextExerciseName)!"
        )
        
        let updatedState = RestTimerActivityAttributes.ContentState(
            timerState: .transitionTimerRunning,
            exerciseName: "Transition",
            endTime: endTime,
            restDuration: duration,
            nextExerciseName: nextExerciseName,
            nextExerciseTarget: target,
            nextExerciseNotes: notes
        )
        
        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil,
                    relevanceScore: 50
                )
            )
        }
    }
    
    // MARK: - Timer Expiration
    
    func setRestTimerExpired(currentExerciseName: String, currentSetNumber: Int) {
        guard let activity = currentActivity else { return }
        
        isTimerExpired = true
        cancelNotification()
        
        let updatedState = RestTimerActivityAttributes.ContentState(
            timerState: .restTimerExpired,
            exerciseName: currentExerciseName,
            currentSetNumber: currentSetNumber
        )
        
        let alertConfiguration = AlertConfiguration(
            title: "Rest Complete!",
            body: "Time to start your next set",
            sound: .default
        )
        
        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil,
                    relevanceScore: 100
                ),
                alertConfiguration: alertConfiguration
            )
            
            // Trigger haptic feedback in foreground if active
            if UIApplication.shared.applicationState == .active {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    func setTransitionTimerExpired(nextExerciseName: String, target: String?, notes: String?) {
        guard let activity = currentActivity else { return }
        
        isTimerExpired = true
        cancelNotification()
        
        let updatedState = RestTimerActivityAttributes.ContentState(
            timerState: .transitionTimerExpired,
            exerciseName: "Transition",
            nextExerciseName: nextExerciseName,
            nextExerciseTarget: target,
            nextExerciseNotes: notes
        )
        
        let alertConfiguration = AlertConfiguration(
            title: "Ready!",
            body: "Get ready for \(nextExerciseName)",
            sound: .default
        )
        
        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil,
                    relevanceScore: 100
                ),
                alertConfiguration: alertConfiguration
            )
            
            // Trigger haptic feedback in foreground if active
            if UIApplication.shared.applicationState == .active {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    // MARK: - User Acknowledgment
    
    func acknowledgeExpiredTimer(exerciseName: String, setNumber: Int) {
        guard currentActivity != nil else { return }
        
        isTimerExpired = false
        updateToIdle(exerciseName: exerciseName, setNumber: setNumber)
    }
    
    // MARK: - State Query
    
    func getIsTimerExpired() -> Bool {
        return isTimerExpired
    }
}
