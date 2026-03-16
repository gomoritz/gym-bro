//
//  HealthKitManager.swift
//  gym-bro Watch
//

import Foundation
import HealthKit

@Observable
class HealthKitManager: NSObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    var currentHeartRate: Double?
    var activeCalories: Double = 0
    var isWorkoutActive: Bool = false

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Workout Session

    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self

            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("Failed to begin workout collection: \(error.localizedDescription)")
                }
            }

            isWorkoutActive = true
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }

    func endWorkout() {
        guard let session = workoutSession else { return }

        session.end()

        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            guard let self = self else { return }
            if let error = error {
                print("Failed to end collection: \(error.localizedDescription)")
                return
            }

            self.workoutBuilder?.finishWorkout { workout, error in
                if let error = error {
                    print("Failed to finish workout: \(error.localizedDescription)")
                }
            }
        }

        isWorkoutActive = false
        currentHeartRate = nil
        activeCalories = 0
    }

    // MARK: - Data Processing

    private func processHeartRateSamples(_ samples: [HKQuantitySample]) {
        guard let lastSample = samples.last else { return }
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let value = lastSample.quantity.doubleValue(for: heartRateUnit)
        currentHeartRate = value
    }

    private func processCalorieSamples(_ samples: [HKQuantitySample]) {
        let calorieUnit = HKUnit.kilocalorie()
        let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: calorieUnit) }
        activeCalories += total
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        switch toState {
        case .running:
            isWorkoutActive = true
        case .ended:
            isWorkoutActive = false
        default:
            break
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            if let statistics = workoutBuilder.statistics(for: quantityType) {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    if let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                        Task { @MainActor in
                            self.currentHeartRate = value
                        }
                    }

                case HKQuantityType(.activeEnergyBurned):
                    let calorieUnit = HKUnit.kilocalorie()
                    if let value = statistics.sumQuantity()?.doubleValue(for: calorieUnit) {
                        Task { @MainActor in
                            self.activeCalories = value
                        }
                    }

                default:
                    break
                }
            }
        }
    }
}
