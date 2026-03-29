//
//  WorkoutTimelineViewModel.swift
//  gym-bro
//

import Foundation

@Observable
class WorkoutTimelineViewModel {
    private(set) var predictor: WorkoutPredictor?
    private(set) var prediction: WorkoutPrediction?
    private(set) var completedExercises: [Exercise]?
    private(set) var workoutProgress: Double?

    func update(sessionManager: SessionManager, allSessions: [WorkoutSession]) {
        completedExercises = WorkoutProgressService.getCompletedExercises(
            session: sessionManager.activeSession,
            split: sessionManager.currentSplit,
            currentExerciseId: sessionManager.currentExercise?.id
        )

        workoutProgress = WorkoutProgressService.calculateWorkoutProgress(
            split: sessionManager.currentSplit,
            currentExercise: sessionManager.currentExercise,
            currentSetNumber: sessionManager.currentSetNumber,
            completedExercises: completedExercises
        )

        updatePrediction(sessionManager: sessionManager, allSessions: allSessions)
    }

    private func updatePrediction(sessionManager: SessionManager, allSessions: [WorkoutSession]) {
        guard let session = sessionManager.activeSession,
              let split = sessionManager.currentSplit else {
            prediction = nil
            return
        }

        let pred = WorkoutPredictor(
            currentSession: session,
            split: split,
            allSessions: allSessions,
            completedExercises: completedExercises ?? [],
            currentExercise: sessionManager.currentExercise,
            remainingExercises: sessionManager.remainingExercisesInSplit
        )

        self.predictor = pred
        self.prediction = pred.generatePrediction()
    }

    func exerciseDuration(for exercise: Exercise, sessionManager: SessionManager) -> TimeInterval? {
        let sets = WorkoutProgressService.getSetsForExercise(exercise, in: sessionManager.activeSession)
        return WorkoutProgressService.exerciseDuration(for: exercise, sets: sets)
    }

    func setsForExercise(_ exercise: Exercise, sessionManager: SessionManager) -> [WorkoutSet]? {
        WorkoutProgressService.getSetsForExercise(exercise, in: sessionManager.activeSession)
    }

    var hasEnhancedDataInPrediction: Bool {
        guard let prediction else { return false }
        return prediction.exercisePredictions.values.contains { $0.hasEnhancedData }
    }

    func daysSinceLastWorkout(sessionManager: SessionManager, allSessions: [WorkoutSession]) -> Int? {
        guard let split = sessionManager.currentSplit else { return nil }

        let previousSessions = allSessions.filter { session in
            session.splitId == split.id &&
            session.id != sessionManager.activeSession?.id &&
            session.startTime < (sessionManager.activeSession?.startTime ?? Date())
        }.sorted { $0.startTime > $1.startTime }

        guard let lastSession = previousSessions.first,
              let currentStart = sessionManager.activeSession?.startTime else { return nil }

        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: lastSession.startTime, to: currentStart).day
    }
}
