//
//  RestTimerView.swift
//  gym-bro
//
//  Created by Moritz Gößl on 12.01.26.
//

import SwiftUI

struct RestTimerView: View {
    @Bindable var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            timerColor
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Circular progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 20)
                        .frame(width: 280, height: 280)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    
                    // Timer text
                    VStack(spacing: 8) {
                        Text(formatTime(sessionManager.restTimeRemaining))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        
                        Text(sessionManager.transitionToExercise != nil ? "Next Up" : "Rest Timer")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                // Exercise Details (moved outside circle)
                if let transitionExercise = sessionManager.transitionToExercise {
                    VStack(spacing: 8) {
                        Text(transitionExercise.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        // Target/Notes
                        if let target = getTargetString(for: transitionExercise) {
                                Text(target)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        
                        if let notes = transitionExercise.notes {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .fixedSize(horizontal: false, vertical: true) // Allow unlimited height
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Status text
                if sessionManager.restTimeRemaining > 0 {
                    Text(sessionManager.transitionToExercise != nil ? "Get Ready!" : "Rest in progress")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                } else {
                    Text(sessionManager.transitionToExercise != nil ? "Let's Go!" : "Rest complete!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                
                // Dismiss button
                Button(action: {
                    // Always ensure timer is stopped/invalidated when manually continuing
                    // If it was running, toggle stops it.
                    // If it was finished (but state kept active for UI), toggle stops it.
                    sessionManager.toggleTimer()
                    dismiss()
                }) {
                    Text(sessionManager.transitionToExercise != nil ? "Start Exercise" : "Continue Workout")
                        .font(.headline)
                        .foregroundStyle(timerColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Set up auto-dismiss callback
            sessionManager.onTimerComplete = { [weak sessionManager] in
                // Wait 2 seconds to show "Rest complete!" state
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Check if view is still presented (simplest way is just to act)
                    // We must STOP the timer state so it doesn't stay "active=true" with 0 time.
                    sessionManager?.toggleTimer()
                    dismiss()
                }
            }
        }
        .onDisappear {
            // Clean up callback
            sessionManager.onTimerComplete = nil
        }
    }
    
    private var progress: CGFloat {
        CGFloat(sessionManager.restTimeRemaining / sessionManager.restTimerDuration)
    }
    
    private var timerColor: Color {
        if sessionManager.restTimeRemaining <= 0 {
            return .red
        }
        return sessionManager.transitionToExercise != nil ? .blue : .green
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func getTargetString(for exercise: Exercise) -> String? {
        if exercise.hasTarget {
            var parts: [String] = []
            if let sets = exercise.targetSets {
                parts.append("\(sets) sets")
            }
            if let min = exercise.minReps, let max = exercise.maxReps {
                parts.append("\(min)-\(max) reps")
            }
            if let weight = exercise.targetWeight {
                parts.append("@ \(Int(weight))kg")
            }
            return parts.joined(separator: " ")
        }
        return nil
    }
}

#Preview {
    let manager = SessionManager()
    manager.restTimeRemaining = 90
    manager.isRestTimerActive = true
    return RestTimerView(sessionManager: manager)
}
