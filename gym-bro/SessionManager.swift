//
//  SessionManager.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import Foundation
import SwiftData

@Observable
class SessionManager: Identifiable, Hashable {
    let id = UUID()
    
    var currentSplit: Split?
    var currentExerciseIndex: Int = 0
    var isRestTimerActive: Bool = false
    var restTimerDuration: TimeInterval = 120 // 2 minutes
    var restTimeRemaining: TimeInterval = 120
    var activeSession: WorkoutSession?
    
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
    
    func toggleTimer() {
        if isRestTimerActive {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        restTimeRemaining = restTimerDuration
        isRestTimerActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.restTimeRemaining > 0 {
                self.restTimeRemaining -= 1
            } else {
                // Timer finished, but keep it visible in red state
                // User must manually dismiss it
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRestTimerActive = false
        restTimeRemaining = restTimerDuration
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
