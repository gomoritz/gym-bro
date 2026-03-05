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
            name: "Stepper"
        ),
        Exercise(
            name: "Fahrrad"
        ),
        Exercise(
            name: "Chest Press",
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        ),
        Exercise(
            name: "Shoulder Press",
            targetSets: 4,
            minReps: 6,
            maxReps: 8
        ),
        Exercise(
            name: "Biceps Curl",
            targetSets: 3,
            minReps: 10,
            maxReps: 15
        ),
        Exercise(
            name: "Row",
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        ),
        Exercise(
            name: "Leg Press",
            targetSets: 4,
            minReps: 10,
            maxReps: 15
        ),
        Exercise(
            name: "Calf Extensions",
            targetSets: 4,
            minReps: 8,
            maxReps: 12
        ),
        Exercise(
            name: "Stairmaster"
        )
    ]
}

extension RandomAccessCollection {
    func elements(at indices: [Index]) -> [Element] {
        indices.map { self[$0] }
    }
}
