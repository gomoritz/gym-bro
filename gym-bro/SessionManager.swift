//
//  SessionManager.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import Foundation
import SwiftData
import UIKit

@Observable
class SessionManager: Identifiable, Hashable {
    let id = UUID()
    
    var currentSplit: Split?
    var currentExerciseIndex: Int = 0
    var isRestTimerActive: Bool = false
    var restTimerDuration: TimeInterval = 20 // 2 minutes
    var restTimeRemaining: TimeInterval = 120
    var activeSession: WorkoutSession?
    var onTimerComplete: (() -> Void)?
    
    private var modelContext: ModelContext?
    private var timer: Timer?
    
    // MARK: - Computed Properties
    
    var currentExercise: Exercise? {
        guard let split = currentSplit,
              let exercises = split.exercises,
              currentExerciseIndex < exercises.count else {
            return nil
        }
        return exercises[currentExerciseIndex]
    }
    
    var currentSetNumber: Int {
        guard let session = activeSession,
              let currentEx = currentExercise,
              let sets = session.sets else {
            return 1
        }
        
        // Count how many sets have been logged for the current exercise
        let setsForCurrentExercise = sets.filter { $0.exercise?.id == currentEx.id }
        return setsForCurrentExercise.count + 1
    }
    
    var lastSet: WorkoutSet? {
        guard let session = activeSession,
              let currentEx = currentExercise,
              let sets = session.sets else {
            return nil
        }
        
        // Get the most recent set for the current exercise
        return sets
            .filter { $0.exercise?.id == currentEx.id }
            .sorted { $0.startTime > $1.startTime }
            .first
    }
    
    var isSessionActive: Bool {
        return activeSession != nil
    }
    
    // MARK: - Session Management
    
    func startSession(for split: Split, context: ModelContext) {
        self.currentSplit = split
        self.currentExerciseIndex = 0
        self.modelContext = context
        
        let session = WorkoutSession(
            startTime: Date.now,
            split: split
        )
        
        context.insert(session)
        self.activeSession = session
    }
    
    func logSet(weight: Double, reps: Int) {
        guard let session = activeSession,
              let exercise = currentExercise,
              let context = modelContext else {
            return
        }
        
        // Create a new WorkoutSet
        let workoutSet = WorkoutSet(
            startTime: Date.now,
            weight: weight,
            reps: reps,
            exercise: exercise,
            session: session
        )
        
        context.insert(workoutSet)
        
        // Add to session's sets
        if session.sets == nil {
            session.sets = []
        }
        session.sets?.append(workoutSet)
        
        // Add to exercise's history
        if exercise.history == nil {
            exercise.history = []
        }
        exercise.history?.append(workoutSet)
        
        // Save the context
        try? context.save()
    }
    
    func logDurationSet(minutes: Int) {
        guard let session = activeSession,
              let exercise = currentExercise,
              let context = modelContext else {
            return
        }
        
        // Create a new WorkoutSet with duration
        let workoutSet = WorkoutSet(
            startTime: Date.now,
            duration: minutes,
            exercise: exercise,
            session: session
        )
        
        context.insert(workoutSet)
        
        // Add to session's sets
        if session.sets == nil {
            session.sets = []
        }
        session.sets?.append(workoutSet)
        
        // Add to exercise's history
        if exercise.history == nil {
            exercise.history = []
        }
        exercise.history?.append(workoutSet)
        
        // Save the context
        try? context.save()
    }
    
    func nextExercise() -> Bool {
        guard let split = currentSplit,
              let exercises = split.exercises else {
            return false
        }
        
        // Stop the timer if active
        if isRestTimerActive {
            toggleTimer()
        }
        
        // Check if there's a next exercise
        if currentExerciseIndex < exercises.count - 1 {
            currentExerciseIndex += 1
            return true
        }
        
        return false
    }
    
    func endSession() {
        guard let session = activeSession,
              let context = modelContext else {
            return
        }
        
        session.endTime = Date.now
        try? context.save()
        
        // Clean up
        activeSession = nil
        currentSplit = nil
        currentExerciseIndex = 0
        
        if isRestTimerActive {
            toggleTimer()
        }
    }
    
    // MARK: - Timer Management
    
    private var timerEndTime: Date?
    
    // ...

    func toggleTimer() {
        if isRestTimerActive {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        // Request notification permission if needed
        Task { @MainActor in
            RestTimerActivityManager.shared.requestNotificationAuthorization()
        }
        
        restTimeRemaining = restTimerDuration
        timerEndTime = Date().addingTimeInterval(restTimerDuration)
        isRestTimerActive = true
        
        // Start Live Activity
        let exerciseName = currentExercise?.name ?? "Rest"
        Task { @MainActor in
            RestTimerActivityManager.shared.startActivity(
                exerciseName: exerciseName,
                duration: restTimerDuration
            )
        }
        
        // Timer fires every 0.1s for smoother UI updates, though UI might throttle
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.timerEndTime else { return }
            
            let remaining = endTime.timeIntervalSinceNow
            
            if remaining > 0 {
                self.restTimeRemaining = remaining
                // We don't need to update Live Activity repeatedly for countdown 
                // because we'll use Text(timerInterval:)
            } else {
                // Timer finished
                self.timer?.invalidate()
                self.timer = nil
                self.isRestTimerActive = false
                self.restTimeRemaining = 0
                
                // Update Live Activity to show expired state (0 seconds)
                Task { @MainActor in
                    RestTimerActivityManager.shared.updateActivity(
                        remainingSeconds: 0
                    )
                    
                    // If we are in the foreground, we can cancel the pending notification
                    // (optional, depending on desired behavior, but good for "alert only if background")
                     if UIApplication.shared.applicationState == .active {
                        RestTimerActivityManager.shared.cancelNotification()
                    }
                }
                
                self.onTimerComplete?()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerEndTime = nil
        isRestTimerActive = false
        restTimeRemaining = restTimerDuration
        
        // End Live Activity manually
        Task { @MainActor in
            RestTimerActivityManager.shared.endActivity()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: SessionManager, rhs: SessionManager) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
