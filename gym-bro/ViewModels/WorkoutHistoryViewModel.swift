//
//  WorkoutHistoryViewModel.swift
//  gym-bro
//

import Foundation

@Observable
class WorkoutHistoryViewModel {
    private(set) var groupedSessions: [Date: [WorkoutSession]] = [:]
    private(set) var orphanedCount: Int = 0

    var selectedSessions: Set<UUID> = []
    var isEditMode: Bool = false

    func update(sessions: [WorkoutSession]) {
        groupedSessions = SessionGroupingService.groupByWeek(sessions)
        orphanedCount = SessionGroupingService.orphanedSessionsCount(in: sessions)
    }

    func uniqueExerciseCount(in session: WorkoutSession) -> Int? {
        SessionGroupingService.uniqueExerciseCount(in: session)
    }

    func toggleSelection(_ session: WorkoutSession) {
        if selectedSessions.contains(session.id) {
            selectedSessions.remove(session.id)
        } else {
            selectedSessions.insert(session.id)
        }
    }

    func toggleEditMode() {
        isEditMode.toggle()
        if !isEditMode {
            selectedSessions.removeAll()
        }
    }

    func clearSelection() {
        selectedSessions.removeAll()
        isEditMode = false
    }
}
