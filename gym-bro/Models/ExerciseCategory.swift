//
//  ExerciseCategory.swift
//  gym-bro
//
//  Created by Claude on 16.02.26.
//

import Foundation
import SwiftData

@Model
class ExerciseCategory: Identifiable {
    var id: UUID = UUID()

    var name: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Exercise.category)
    var exercises: [Exercise]?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
