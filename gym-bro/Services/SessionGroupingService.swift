//
//  SessionGroupingService.swift
//  gym-bro
//

import Foundation

struct SessionGroupingService {
    static func groupByWeek(_ sessions: [WorkoutSession]) -> [Date: [WorkoutSession]] {
        Dictionary(grouping: sessions) { session in
            startOfWeek(for: session.startTime)
        }
    }

    static func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    static func orphanedSessionsCount(in sessions: [WorkoutSession]) -> Int {
        sessions.filter { $0.split == nil }.count
    }

    static func uniqueExerciseCount(in session: WorkoutSession) -> Int? {
        guard let sets = session.sets else { return nil }
        let uniqueExercises = Set(sets.compactMap { $0.exercise?.id })
        return uniqueExercises.isEmpty ? nil : uniqueExercises.count
    }
}
