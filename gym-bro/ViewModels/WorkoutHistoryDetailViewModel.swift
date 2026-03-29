//
//  WorkoutHistoryDetailViewModel.swift
//  gym-bro
//

import Foundation

@Observable
class WorkoutHistoryDetailViewModel {
    let session: WorkoutSession

    private(set) var stats: SessionAnalyticsService.SessionStats
    private(set) var volumeBreakdown: [SessionAnalyticsService.ExerciseVolume]
    private(set) var personalRecords: [SessionAnalyticsService.PersonalRecord]
    private(set) var previousComparison: SessionAnalyticsService.WorkoutComparison?
    private(set) var insights: [String]
    private(set) var orderedExercises: [Exercise]?

    init(session: WorkoutSession, allSessions: [WorkoutSession]) {
        self.session = session
        self.stats = SessionAnalyticsService.computeStats(for: session)
        self.volumeBreakdown = SessionAnalyticsService.computeVolumeBreakdown(for: session)
        self.personalRecords = SessionAnalyticsService.detectPersonalRecords(session: session, allSessions: allSessions)
        self.previousComparison = SessionAnalyticsService.previousWorkoutComparison(session: session, allSessions: allSessions)
        self.insights = SessionAnalyticsService.generateInsights(
            session: session,
            stats: self.stats,
            records: self.personalRecords,
            comparison: self.previousComparison
        )
        self.orderedExercises = SessionAnalyticsService.getOrderedExercises(for: session)
    }

    func setsForExercise(_ exercise: Exercise) -> [WorkoutSet]? {
        SessionAnalyticsService.getSetsForExercise(exercise, in: session)
    }

    func volumeForExercise(_ exercise: Exercise) -> Double? {
        SessionAnalyticsService.exerciseVolume(for: exercise, in: session)
    }
}
