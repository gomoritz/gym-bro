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
    var id: UUID

    var name: String

    @Relationship(inverse: \Exercise.splits)
    var exercises: [Exercise]?

    init(id: UUID = UUID(), name: String, exercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
