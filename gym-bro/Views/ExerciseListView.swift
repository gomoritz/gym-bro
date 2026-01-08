//
//  ExerciseListView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var isPresentingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises) { exercise in
                    NavigationLink {
                        Text("Edit \(exercise.name)")
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .font(.headline)

                            Text(exercise.splitNames ?? "No splits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
            }
            .navigationTitle("Exercises")
            .toolbar {
                Button("Add", systemImage: "plus") {
                    isPresentingAddSheet = true
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                AddExerciseSheet()
            }
        }
    }

    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(exercises[index])
            }
        }
    }
}

struct AddExerciseSheet: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var notes = ""

    @State private var hasTarget = true
    @State private var targetSets = 4
    @State private var targetWeight = 10.0
    @State private var minReps = 8
    @State private var maxReps = 12

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...)
                    Toggle("Set target", isOn: $hasTarget)
                }

                if hasTarget {
                    Section("Target") {
                        Stepper(
                            "**\(targetSets) sets**",
                            value: $targetSets,
                            in: 1...8
                        )
                        Stepper(
                            "**\(minReps) reps** minimum",
                            value: $minReps,
                            in: 1...maxReps
                        )
                        Stepper(
                            "**\(maxReps) reps** maximum",
                            value: $maxReps,
                            in: minReps...100
                        )

                        VStack {
                            Stepper(
                                "**\(String(format: "%.1f", targetWeight)) kg** weight",
                                value: $targetWeight,
                                in: 1.0...200.0,
                                step: 0.5
                            )

                            Slider(value: $targetWeight, in: 1...200, step: 0.5)
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .toolbar {
                Button("Save") {
                    let newExercise = Exercise(
                        name: name,
                        notes: !notes.trimming().isEmpty ? notes : nil,
                        targetWeight: hasTarget ? targetWeight : nil,
                        targetSets: hasTarget ? targetSets : nil,
                        minReps: hasTarget ? minReps : nil,
                        maxReps: hasTarget ? maxReps : nil
                    )

                    modelContext.insert(newExercise)
                    dismiss()
                }
                .disabled(name.trimming().isEmpty)
            }
        }
    }
}

#Preview(traits: .sampleData) {
    ExerciseListView()
    //AddExerciseSheet()
}
