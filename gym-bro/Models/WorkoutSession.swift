//
//  WorkoutSession.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation
import SwiftData

@Model
class WorkoutSession: Identifiable {
    var id: UUID

    var startTime: Date
    var endTime: Date?
    var location: String?

    @Relationship(deleteRule: .cascade)
    var split: Split?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet]?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        location: String? = nil,
        split: Split? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.split = split
    }
}
