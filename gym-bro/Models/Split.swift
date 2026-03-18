//
//  Split.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation
import SwiftData

@Model
class Split: Identifiable {
    var id: UUID = UUID()

    var name: String = ""

    @Relationship(inverse: \Exercise.splits)
    var exercises: [Exercise]?

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.split)
    var sessions: [WorkoutSession]?

    init(id: UUID = UUID(), name: String, exercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
