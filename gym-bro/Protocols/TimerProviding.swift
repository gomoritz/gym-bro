//
//  TimerProviding.swift
//  gym-bro
//

import Foundation

protocol TimerProviding: AnyObject {
    var isActive: Bool { get }
    var duration: TimeInterval { get }
    var timeRemaining: TimeInterval { get }
    var isExpired: Bool { get set }
    var onTimerTick: (() -> Void)? { get set }
    var onTimerExpired: (() -> Void)? { get set }
    func start(duration: TimeInterval)
    func stop()
    func acknowledgeExpiry()
}
