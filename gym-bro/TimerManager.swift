//
//  TimerManager.swift
//  gym-bro
//

import Foundation
import AudioToolbox

@Observable
class TimerManager {
    var isActive: Bool = false
    var duration: TimeInterval = Constants.Timer.defaultRestDuration
    var timeRemaining: TimeInterval = Constants.Timer.defaultRestDuration
    var isExpired: Bool = false

    private var timer: Timer?
    private var endTime: Date?

    // Callbacks for live activity updates (set by SessionManager)
    var onTimerTick: (() -> Void)?
    var onTimerExpired: (() -> Void)?

    func start(duration: TimeInterval) {
        self.duration = duration
        self.timeRemaining = duration
        self.endTime = Date().addingTimeInterval(duration)
        self.isActive = true
        self.isExpired = false

        timer = Timer.scheduledTimer(withTimeInterval: Constants.Timer.tickInterval, repeats: true) { [weak self] _ in
            guard let self = self, let endTime = self.endTime else { return }

            let remaining = endTime.timeIntervalSinceNow

            if remaining > 0 {
                self.timeRemaining = remaining
            } else {
                self.timer?.invalidate()
                self.timer = nil
                self.timeRemaining = 0
                self.isExpired = true
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                self.onTimerExpired?()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endTime = nil
        isActive = false
        isExpired = false
        timeRemaining = duration
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start(duration: duration)
        }
    }

    func acknowledgeExpiry() {
        if isExpired {
            isExpired = false
        }
    }

    deinit {
        timer?.invalidate()
    }
}
