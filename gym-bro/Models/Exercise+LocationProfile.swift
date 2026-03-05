//
//  Exercise+LocationProfile.swift
//  gym-bro
//

import Foundation

extension Exercise {
    func profile(for location: GymLocation) -> ExerciseLocationProfile? {
        locationProfiles?.first { $0.location?.id == location.id }
    }

    func effectiveTargetWeight(for location: GymLocation?) -> Double? {
        guard let location else { return targetWeight }
        return profile(for: location)?.targetWeight ?? targetWeight
    }

    func effectiveNotes(for location: GymLocation?) -> String? {
        guard let location else { return notes }
        return profile(for: location)?.notes ?? notes
    }

    func mostRecentIncrease(excluding location: GymLocation) -> ExerciseLocationProfile? {
        locationProfiles?
            .filter { $0.location?.id != location.id && $0.lastWeightIncrease != nil }
            .sorted { ($0.lastWeightIncrease ?? .distantPast) > ($1.lastWeightIncrease ?? .distantPast) }
            .first
    }
}
