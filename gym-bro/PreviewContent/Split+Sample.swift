//
//  Split+Sample.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation

extension Split {
    static let sampleData: [Split] = [
        Split(
            name: "Push",
            exercises: Exercise.sampleData.elements(at: [0, 2, 3])
        ),
        Split(
            name: "Pull",
            exercises: Exercise.sampleData.elements(at: [0, 4, 5])
        ),
        Split(
            name: "Legs",
            exercises: Exercise.sampleData.elements(at: [1, 6, 7])
        ),
    ]
}
