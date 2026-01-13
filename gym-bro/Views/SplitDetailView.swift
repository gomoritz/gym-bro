//
//  SplitDetailView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftData
import SwiftUI

struct SplitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionManager.self) private var sessionManager

    @Bindable var split: Split

    @State private var isPresentingExercisePicker = false
    @State private var isWorkoutActive = false

    var body: some View {
        List {
            Section("Exercises") {
                if let exercises = split.exercises, !exercises.isEmpty {
                    ForEach(exercises) { exercise in
                        Text(exercise.name)
                    }
                    .onDelete(perform: removeExerciseFromSplit)
                    .onMove(perform: moveExercise)
                } else {
                    Text("No exercises yet")
                        .foregroundStyle(.secondary)
                }
            }

            Button("Add exercise") {
                isPresentingExercisePicker = true
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
            
            if let exercises = split.exercises, !exercises.isEmpty {
                Button("Start Workout") {
                    sessionManager.startSession(for: split, context: modelContext)
                    isWorkoutActive = true
                }
            }
        }
        .sheet(isPresented: $isPresentingExercisePicker) {
            ExercisePickerView(split: split)
        }
        .onDisappear {
            try? modelContext.save()
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
                        Text(exercise.name)
                        Spacer()
                        if split.exercises?.contains(exercise) == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleExercise(exercise)
                    }
                }
            }
            .navigationTitle("Select exercises")
        }
    }

    func toggleExercise(_ exercise: Exercise) {
        // Ensure the array exists
        if split.exercises == nil { split.exercises = [] }

        if let index = split.exercises?.firstIndex(of: exercise) {
            // If it's already there, remove it (toggle off)
            split.exercises?.remove(at: index)
        } else {
            // If not there, append it (toggle on)
            split.exercises?.append(exercise)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Split.name) var splits: [Split]
    SplitDetailView(split: splits[0])
}
