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
            split: Split.sampleData[2],
            gymLocationName: "FIT STAR Erlangen Innenstadt"
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
            split: Split.sampleData[1],
            gymLocationName: "FIT STAR Sportsclub Lauf"
        ),
        WorkoutSession(
            startTime: Calendar.current.date(
                byAdding: .hour,
                value: -1,
                to: Date()
            )!,
            split: Split.sampleData[0],
            gymLocationName: "FIT STAR Sportsclub Lauf"
        ),
    ]
}
