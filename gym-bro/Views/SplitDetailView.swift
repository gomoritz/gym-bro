//
//  SplitDetailView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 08.01.26.
//

import SwiftData
import SwiftUI
import os

private let logger = Logger(subsystem: "com.gym-bro", category: "SplitDetailView")

struct SplitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager

    @Bindable var split: Split

    @State private var isPresentingExercisePicker = false
    @State private var isWorkoutActive = false
    @State private var workoutStarted = false

    var body: some View {
        List {
            Section("Exercises") {
                if let exercises = split.exercises, !exercises.isEmpty {
                    ForEach(exercises) { exercise in
                        HStack {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(exercise.name)
                                    .font(.headline)

                                if let target = exercise.targetString {
                                    Text(target)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let category = exercise.category {
                                Text(category.name)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .background(.blue.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                    .onDelete(perform: removeExerciseFromSplit)
                    .onMove(perform: moveExercise)
                } else {
                    Text("No exercises yet")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    isPresentingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }

            if let exercises = split.exercises, !exercises.isEmpty {
                Section {
                    Button {
                        workoutStarted.toggle()
                        sessionManager.startSession(for: split, context: modelContext)
                        isWorkoutActive = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Workout", systemImage: "play.fill")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .frame(minHeight: Theme.TouchTarget.comfortable)
                        .listRowBackground(
                        LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: workoutStarted)
                    .listRowBackground(
                        LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                }
            }
        }
        .navigationTitle(split.name)
        .fullScreenCover(isPresented: $isWorkoutActive) {
            NavigationStack {
                ActiveSessionView(sessionManager: sessionManager)
            }
        }
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $isPresentingExercisePicker) {
            ExercisePickerView(split: split)
        }
        .onDisappear {
            do {
                try modelContext.save()
            } catch {
                logger.error("Failed to save split changes: \(error.localizedDescription)")
            }
        }
    }

    private func removeExerciseFromSplit(offsets: IndexSet) {
        split.exercises?.remove(atOffsets: offsets)
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        split.exercises?.move(fromOffsets: source, toOffset: destination)
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Exercise.name) var allExercises: [Exercise]
    var split: Split

    var body: some View {
        NavigationStack {
            List {
                ForEach(allExercises) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(exercise.name)
                                .font(.headline)

                            if let target = exercise.targetString {
                                Text(target)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if split.exercises?.contains(exercise) == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.tertiary)
                                .font(.title2)
                        }
                    }
                    .frame(minHeight: Theme.TouchTarget.minimum)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2)) {
                            toggleExercise(exercise)
                        }
                    }
                }
            }
            .navigationTitle("Select exercises")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    func toggleExercise(_ exercise: Exercise) {
        if split.exercises == nil { split.exercises = [] }

        if let index = split.exercises?.firstIndex(of: exercise) {
            split.exercises?.remove(at: index)
        } else {
            split.exercises?.append(exercise)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Split.name) var splits: [Split]
    SplitDetailView(split: splits[0])
}
