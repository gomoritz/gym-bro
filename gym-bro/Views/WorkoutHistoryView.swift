//
//  WorkoutHistoryView.swift
//  gym-bro
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startTime, order: .reverse) private var sessions: [WorkoutSession]

    @State private var selectedSessions: Set<UUID> = []
    @State private var isEditMode = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyStateView
                } else {
                    workoutListView
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !sessions.isEmpty {
                        Button(isEditMode ? "Done" : "Select") {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedSessions.removeAll()
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete \(selectedSessions.count) workout\(selectedSessions.count > 1 ? "s" : "")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedWorkouts()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 70))
                .foregroundStyle(.gray)

            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your workout history will appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var workoutListView: some View {
        List {
            if orphanedSessionsCount > 0 {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(orphanedSessionsCount) workout\(orphanedSessionsCount > 1 ? "s" : "") need\(orphanedSessionsCount == 1 ? "s" : "") a split assigned")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("Tap on affected workouts to assign a split")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.orange.opacity(0.1))
                }
            }

            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                Section(header: sectionHeader(for: date)) {
                    ForEach(groupedSessions[date] ?? []) { session in
                        if isEditMode {
                            HStack(spacing: 12) {
                                Image(systemName: selectedSessions.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedSessions.contains(session.id) ? .blue : .gray)
                                    .font(.title2)

                                workoutRow(session)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(session)
                            }
                        } else {
                            NavigationLink {
                                WorkoutHistoryDetailView(session: session)
                            } label: {
                                workoutRow(session)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if isEditMode && !selectedSessions.isEmpty {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete \(selectedSessions.count) workout\(selectedSessions.count > 1 ? "s" : "")")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
    }

    private func sectionHeader(for weekStart: Date) -> some View {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let startFormatted = sectionDateFormatter.string(from: weekStart)
        let endFormatted = sectionDateFormatter.string(from: weekEnd)

        return Text("\(startFormatted) – \(endFormatted)")
            .font(.headline)
            .textCase(.uppercase)
    }

    private func workoutRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.displaySplitName)
                            .font(.headline)

                        if session.split == nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(timeFormatter.string(from: session.startTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let duration = session.endTime?.timeIntervalSince(session.startTime) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let exerciseCount = uniqueExerciseCount(in: session) {
                            Text("\(exerciseCount) exercise\(exerciseCount > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let location = session.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(location)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var groupedSessions: [Date: [WorkoutSession]] {
        Dictionary(grouping: sessions) { session in
            startOfWeek(for: session.startTime)
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    private var orphanedSessionsCount: Int {
        sessions.filter { $0.split == nil }.count
    }

    private func uniqueExerciseCount(in session: WorkoutSession) -> Int? {
        guard let sets = session.sets else { return nil }
        let uniqueExercises = Set(sets.compactMap { $0.exercise?.id })
        return uniqueExercises.isEmpty ? nil : uniqueExercises.count
    }

    private func toggleSelection(_ session: WorkoutSession) {
        if selectedSessions.contains(session.id) {
            selectedSessions.remove(session.id)
        } else {
            selectedSessions.insert(session.id)
        }
    }

    private func deleteSelectedWorkouts() {
        for sessionId in selectedSessions {
            if let session = sessions.first(where: { $0.id == sessionId }) {
                modelContext.delete(session)
            }
        }
        selectedSessions.removeAll()
        isEditMode = false
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var sectionDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    WorkoutHistoryView()
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self])
}
