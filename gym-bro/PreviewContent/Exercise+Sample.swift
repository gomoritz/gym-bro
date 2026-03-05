//
//  Exercise+Sample.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation

extension Exercise {
    static let sampleData: [Exercise] = [
        Exercise(
            name: "Stepper",
            notes: "10-20 Minuten",
            targetWeight: 6
        ),
        Exercise(
            name: "Fahrrad",
            notes: "15-30 Minuten",
            targetWeight: 11
        ),
        Exercise(
            name: "Chest Press",
            notes: "Brust anspannen",
            targetWeight: 30,
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        ),
        Exercise(
            name: "Shoulder Press",
            targetWeight: 15,
            targetSets: 4,
            minReps: 6,
            maxReps: 8
        ),
        Exercise(
            name: "Biceps Curl",
            targetWeight: 27.5,
            targetSets: 3,
            minReps: 10,
            maxReps: 15
        ),
        Exercise(
            name: "Row",
            targetWeight: 45,
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        ),
        Exercise(
            name: "Leg Press",
            notes: "Sitzhöhe 4",
            targetWeight: 82.5,
            targetSets: 4,
            minReps: 10,
            maxReps: 15
        ),
        Exercise(
            name: "Calf Extensions",
            notes: "Knie nicht strecken!",
            targetWeight: 65,
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        ),
        Exercise(
            name: "Stairmaster",
            notes: "Nicht zu oft",
        )
    ]
}

extension RandomAccessCollection {
    func elements(at indices: [Index]) -> [Element] {
        indices.map { self[$0] }
    }
}
