//
//  WorkoutSet+Sample.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation

extension WorkoutSet {
    static let sampleData: [WorkoutSet] = Exercise.sampleData.enumerated().map {
        (index, exercise) in
        WorkoutSet(
            startTime: Calendar.current.date(
                byAdding: .hour,
                value: -index - 10,
                to: Date()
            )!,
            weight: exercise.hasTarget
                ? Double(Int.random(in: 20...60)) : nil,
            reps: exercise.hasTargetReps
                ? Int.random(in: exercise.minReps!...exercise.maxReps!) : nil,
            exercise: exercise
        )
    }
}
