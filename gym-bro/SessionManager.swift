//
//  SessionManager.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import Foundation
import SwiftData
import UIKit
import AudioToolbox

@Observable
class SessionManager: Identifiable, Hashable {
    let id = UUID()
    
    var currentSplit: Split?
    var currentExerciseIndex: Int = 0
    var transitionToExercise: Exercise?
    var isRestTimerActive: Bool = false
    var restTimerDuration: TimeInterval = 20 // 2 minutes
    var restTimeRemaining: TimeInterval = 120
    var activeSession: WorkoutSession?
    var onTimerComplete: (() -> Void)?
    
    var isChoosingNextExercise: Bool = false
    
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

    var remainingExercisesInSplit: [Exercise] {
        guard let split = currentSplit,
              let exercises = split.exercises,
              let session = activeSession else {
            return []
        }
        
        let completedExerciseIds = Set((session.sets ?? []).compactMap { $0.exercise?.id })
        let currentExerciseId = currentExercise?.id
        
        return exercises.filter { exercise in
            exercise.id != currentExerciseId && !completedExerciseIds.contains(exercise.id)
        }
    }
    
    // MARK: - Session Management
    
    func startSession(for split: Split, context: ModelContext) {
        self.currentSplit = split
        self.currentExerciseIndex = 0
        self.transitionToExercise = nil
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
        
        let remaining = remainingExercisesInSplit
        
        if remaining.count > 1 {
            isChoosingNextExercise = true
            return true
        } else if let next = remaining.first {
            selectNextExercise(next)
            return true
        }
        
        return false
    }

    func selectNextExercise(_ exercise: Exercise) {
        guard let split = currentSplit,
              let exercises = split.exercises,
              let index = exercises.firstIndex(of: exercise) else {
            return
        }
        
        isChoosingNextExercise = false
        currentExerciseIndex = index
        
        // Set transition state
        // Note: we don't increment index anymore, we just set it to the selected one
        // Wait, the current logic increments currentExerciseIndex in stopTimer() if transitionToExercise is set.
        // Let's adjust that.
        
        transitionToExercise = exercise
        
        // Start the transition timer
        startTimer()
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
        transitionToExercise = nil
        
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
        
        // Determine exercise name and details for Live Activity
        let exerciseName: String
        let isTransition: Bool
        let target: String?
        let notes: String?
        
        if let transition = transitionToExercise {
            exerciseName = transition.name
            isTransition = true
            target = getTargetString(for: transition)
            notes = transition.notes
        } else {
            exerciseName = currentExercise?.name ?? "Rest"
            isTransition = false
            target = nil
            notes = nil
        }
        
        // Start Live Activity
        Task { @MainActor in
            RestTimerActivityManager.shared.startActivity(
                exerciseName: exerciseName,
                duration: restTimerDuration,
                isTransition: isTransition,
                target: target,
                notes: notes
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
                
                // 1. Trigger Vibration (Foreground)
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                // 2. Update local state
                self.timer?.invalidate()
                self.timer = nil
                self.restTimeRemaining = 0
                // NOTE: We do NOT set isRestTimerActive = false yet, so that the UI can show "Rest Complete" 
                // and the "Continue" button (which calls toggleTimer) can correctly STOP it (by seeing it matches active).
                
                // 3. Update Live Activity to show expired state (triggers alert in background if allowed)
                Task { @MainActor in
                    RestTimerActivityManager.shared.updateActivity(
                        remainingSeconds: 0
                    )
                    
                    // If in foreground, cancel the notification so it doesn't double-trigger
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
        
        // Handle transition completion if applicable
        if let transition = transitionToExercise,
           let exercises = currentSplit?.exercises,
           let index = exercises.firstIndex(of: transition) {
            currentExerciseIndex = index
            transitionToExercise = nil
        }
        
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
    
    private func getTargetString(for exercise: Exercise) -> String? {
        if exercise.hasTarget {
            var parts: [String] = []
            if let sets = exercise.targetSets {
                parts.append("\(sets) sets")
            }
            if let min = exercise.minReps, let max = exercise.maxReps {
                parts.append("\(min)-\(max) reps")
            }
            if let weight = exercise.targetWeight {
                parts.append("@ \(Int(weight))kg")
            }
            return parts.joined(separator: " ")
        }
        return nil
    }
}
