//
//  RestTimerActivityManager.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import ActivityKit
import Foundation
import UIKit
import UserNotifications

@MainActor
class RestTimerActivityManager: NSObject {
    static let shared = RestTimerActivityManager()
    
    private var currentActivity: Activity<RestTimerActivityAttributes>?
    public var isExpired: Bool = false
    private var activityEndTime: Date?
    
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
            if let error = error {
                print("Notification authorization failed: \(error)")
            }
        }
    }
    
    private func scheduleNotification(for duration: TimeInterval, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Timer Complete"
        content.body = "Time to get back to \(exerciseName)!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: "RestTimerComplete", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    public func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimerComplete"])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - Activity Lifecycle
    
    func startActivity(exerciseName: String, duration: TimeInterval, isTransition: Bool = false, target: String? = nil, notes: String? = nil) {
        // End any existing activity first
        endActivity()
        
        isExpired = false
        activityEndTime = Date().addingTimeInterval(duration)
        
        // Schedule notification
        scheduleNotification(for: duration, exerciseName: exerciseName)
        
        let attributes = RestTimerActivityAttributes(
            exerciseName: exerciseName,
            restDuration: duration,
            isTransition: isTransition,
            target: target,
            notes: notes
        )
        
        let initialState = RestTimerActivityAttributes.ContentState(
            endTime: Date().addingTimeInterval(duration),
            remainingSeconds: duration,
            isExpired: false
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func checkExpiration() {
        guard let endTime = activityEndTime else { return }
        
        if Date() >= endTime {
             // Timer expired while we were away or just now
             updateActivity(remainingSeconds: 0)
        }
    }
    
    func updateActivity(remainingSeconds: TimeInterval) {
        guard let activity = currentActivity else { return }
        
        // If timer reached 0, mark as expired but KEEP activity active
        let expired = remainingSeconds <= 0
        isExpired = expired
        
        // If expired, clear the local end time tracker so we don't re-trigger
        if expired {
            activityEndTime = nil
        }
        
        let updatedState = RestTimerActivityAttributes.ContentState(
             endTime: Date().addingTimeInterval(remainingSeconds), // Note: for expired, this Date logic might be irrelevant for UI if we use timerInterval, but keeping for consistency
            remainingSeconds: remainingSeconds,
            isExpired: expired
        )
        
        let alertConfiguration: AlertConfiguration?
        if expired {
             alertConfiguration = AlertConfiguration(
                title: "Rest Timer Complete!",
                body: "Get back to work!",
                sound: .default
            )
        } else {
            alertConfiguration = nil
        }
        
        Task {
            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: nil,
                    relevanceScore: expired ? 100 : 0 // Low relevance until expired
                ),
                alertConfiguration: alertConfiguration
            )
        }
    }
    
    func endActivity() {
        cancelNotification()
        
        // Capture activity and clear state synchronously to prevent race conditions
        guard let activity = currentActivity else { return }
        
        currentActivity = nil
        activityEndTime = nil
        isExpired = false
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
