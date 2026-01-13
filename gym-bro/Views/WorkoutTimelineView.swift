//
//  WorkoutTimelineView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 13.01.26.
//

import SwiftUI

struct WorkoutTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if sessionManager.activeSession != nil {
                        // Completed exercises
                        if let completedExercises = getCompletedExercises(), !completedExercises.isEmpty {
                            Section("Completed") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(completedExercises, id: \.id) { exercise in
                                        completedExerciseView(exercise)
                                    }
                                }
                            }
                        }

                        // Current exercise
                        if let current = sessionManager.currentExercise {
                            Section("Current") {
                                currentExerciseView(current)
                            }
                        }

                        // Remaining exercises
                        if !sessionManager.remainingExercisesInSplit.isEmpty {
                            Section("Remaining") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(sessionManager.remainingExercisesInSplit) { exercise in
                                        remainingExerciseView(exercise)
                                    }
                                }
                            }
                        }

                        // Estimated completion time
                        Divider()
                            .padding(.vertical, 8)

                        if let completionTime = estimatedCompletionTime {
                            VStack(alignment: .leading, spacing: 8) {
                                Label {
                                    Text("Estimated Completion")
                                        .font(.headline)
                                } icon: {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(.blue)
                                }

                                Text(completionTime)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Timeline")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - View Components

    private func completedExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let sets = getSetsForExercise(exercise) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sets, id: \.id) { workoutSet in
                        setRowView(workoutSet, exercise: exercise)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func currentExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                Label {
                    Text("Set \(sessionManager.currentSetNumber)\(exercise.targetSets.map { " of \($0)" } ?? "")")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "list.number")
                }
                
                Spacer()
                
                if let targetWeight = exercise.targetWeight,
                   let minReps = exercise.minReps,
                   let maxReps = exercise.maxReps {
                    Text("\(Int(targetWeight))kg × \(minReps)-\(maxReps)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 32)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private func remainingExerciseView(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(exercise.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "circle")
                            .foregroundStyle(.gray)
                    }

                    if let targetWeight = exercise.targetWeight,
                       let minReps = exercise.minReps,
                       let maxReps = exercise.maxReps {
                        Text("\(Int(targetWeight))kg × \(minReps)-\(maxReps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let estimatedDuration = estimatedDurationFor(exercise) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Label {
                            Text(estimatedDuration)
                                .font(.caption)
                        } icon: {
                            Image(systemName: "clock")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func setRowView(_ workoutSet: WorkoutSet, exercise: Exercise) -> some View {
        HStack {
            Text("Set")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let weight = workoutSet.weight, let reps = workoutSet.reps {
                Text("\(Int(weight))kg × \(reps)")
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if let duration = workoutSet.duration {
                Text("\(duration) min")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            Text(timeAgoString(from: workoutSet.startTime))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func getCompletedExercises() -> [Exercise]? {
        guard let session = sessionManager.activeSession,
              let sets = session.sets,
              let split = sessionManager.currentSplit,
              let exercises = split.exercises else {
            return nil
        }

        let currentExerciseId = sessionManager.currentExercise?.id
        let completedIds = Set(sets.compactMap { $0.exercise?.id }.filter { $0 != currentExerciseId })
        let completedExercises = exercises.filter { completedIds.contains($0.id) }
        
        // Return in order of first appearance in sets
        var seenIds = Set<UUID>()
        var orderedExercises: [Exercise] = []
        
        for set in sets {
            if let exerciseId = set.exercise?.id, 
               exerciseId != currentExerciseId,
               !seenIds.contains(exerciseId) {
                if let exercise = completedExercises.first(where: { $0.id == exerciseId }) {
                    orderedExercises.append(exercise)
                }
                seenIds.insert(exerciseId)
            }
        }
        
        return orderedExercises.isEmpty ? nil : orderedExercises
    }

    private func getSetsForExercise(_ exercise: Exercise) -> [WorkoutSet]? {
        guard let session = sessionManager.activeSession,
              let sets = session.sets else {
            return nil
        }

        let exerciseSets = sets.filter { $0.exercise?.id == exercise.id }
        return exerciseSets.isEmpty ? nil : exerciseSets
    }

    private func estimatedDurationFor(_ exercise: Exercise) -> String? {
        // Try to get average duration from exercise's history in this session
        if let sessionSets = sessionManager.activeSession?.sets, !sessionSets.isEmpty {
            let exerciseSets = sessionSets.filter { $0.exercise?.id == exercise.id }
            
            if !exerciseSets.isEmpty, let avgSetDuration = calculateAverageSetDuration(exerciseSets) {
                if let targetSets = exercise.targetSets {
                    let totalDuration = avgSetDuration * Double(targetSets)
                    return formatDuration(totalDuration + 60) // Add rest time
                }
            }
        }

        // Fallback to average exercise duration from current session
        if let avgDuration = averageExerciseDurationInSession {
            return formatDuration(avgDuration)
        }

        return nil
    }

    private func calculateAverageSetDuration(_ sets: [WorkoutSet]) -> TimeInterval? {
        guard sets.count >= 2 else { return nil }
        
        var totalDuration: TimeInterval = 0
        for i in 0..<(sets.count - 1) {
            let currentSet = sets[i]
            let nextSet = sets[i + 1]
            totalDuration += nextSet.startTime.timeIntervalSince(currentSet.startTime)
        }
        
        return totalDuration / Double(sets.count - 1)
    }

    private var averageExerciseDurationInSession: TimeInterval? {
        guard let session = sessionManager.activeSession,
              let sets = session.sets,
              sets.count >= 2 else {
            return nil
        }

        let sortedSets = sets.sorted { $0.startTime < $1.startTime }
        
        // Get unique exercise IDs to calculate average per exercise
        var exerciseDurations: [TimeInterval] = []
        var currentExerciseId: UUID? = nil
        var exerciseSets: [WorkoutSet] = []
        
        for set in sortedSets {
            let exerciseId = set.exercise?.id
            
            if exerciseId != currentExerciseId && !exerciseSets.isEmpty {
                // We've moved to a new exercise, calculate duration for previous
                if let avg = calculateAverageSetDuration(exerciseSets) {
                    exerciseDurations.append(avg)
                }
                exerciseSets = []
            }
            
            currentExerciseId = exerciseId
            exerciseSets.append(set)
        }
        
        // Don't forget the last exercise
        if !exerciseSets.isEmpty, let avg = calculateAverageSetDuration(exerciseSets) {
            exerciseDurations.append(avg)
        }

        guard !exerciseDurations.isEmpty else { return nil }
        let avgDuration = exerciseDurations.reduce(0, +) / Double(exerciseDurations.count)
        
        return avgDuration
    }

    private var estimatedCompletionTime: String? {
        guard !sessionManager.remainingExercisesInSplit.isEmpty else {
            return nil
        }

        var remainingTime: TimeInterval = 0

        // Add time for remaining exercises
        for exercise in sessionManager.remainingExercisesInSplit {
            if let estimatedDuration = estimatedDurationFor(exercise) {
                // Parse the formatted duration string
                let components = estimatedDuration.split(separator: " ")
                if let valueString = components.first, let value = Double(valueString) {
                    remainingTime += value * 60 // Convert minutes to seconds
                }
            }
        }

        // Only show completion time if we have a meaningful estimate
        guard remainingTime > 0 else {
            return nil
        }

        let completionDate = Date().addingTimeInterval(remainingTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: completionDate)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 1 {
            return "< 1 min"
        }
        return "\(totalMinutes) min"
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

#Preview {
    let manager = SessionManager()
    return WorkoutTimelineView(sessionManager: manager)
}
