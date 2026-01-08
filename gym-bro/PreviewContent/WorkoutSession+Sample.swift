//
//  WorkoutSession+Sample.swift
//  gym-bro
//
//  Created by Moritz Gößl on 08.01.26.
//

import Foundation

extension WorkoutSession {
    static let sampleData: [WorkoutSession] = [
        WorkoutSession(
            startTime: Calendar.current.date(
                byAdding: .hour,
                value: -50,
                to: Date()
            )!,
            endTime: Calendar.current.date(
                byAdding: .hour,
                value: -48,
                to: Date()
            )!,
            location: "FIT STAR Erlangen Innenstadt",
            split: Split.sampleData[2]
        ),
        WorkoutSession(
            startTime: Calendar.current.date(
                byAdding: .hour,
                value: -26,
                to: Date()
            )!,
            endTime: Calendar.current.date(
                byAdding: .hour,
                value: -24,
                to: Date()
            )!,
            location: "FIT STAR Sportsclub Lauf",
            split: Split.sampleData[1]
        ),
        WorkoutSession(
            startTime: Calendar.current.date(
                byAdding: .hour,
                value: -1,
                to: Date()
            )!,
            location: "FIT STAR Sportsclub Lauf",
            split: Split.sampleData[0]
        ),
    ]
}
