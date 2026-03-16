//
//  WatchExercisePickerView.swift
//  gym-bro Watch
//

import SwiftUI

struct WatchExercisePickerView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss

    var isStartingExercise = false

    private var exercisesToShow: [Exercise] {
        if isStartingExercise {
            return sessionManager.pendingSplit?.exercises ?? []
        } else {
            return sessionManager.remainingExercisesInSplit
        }
    }

    var body: some View {
        NavigationStack {
            List(exercisesToShow) { exercise in
                Button {
                    sessionManager.selectNextExercise(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.headline)
                        if let target = exercise.targetString(for: sessionManager.currentLocation) {
                            Text(target)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isStartingExercise ? "Start With" : "Next")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isStartingExercise {
                            sessionManager.isChoosingStartingExercise = false
                        } else {
                            sessionManager.isChoosingNextExercise = false
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
