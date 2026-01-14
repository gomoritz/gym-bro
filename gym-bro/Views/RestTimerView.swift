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
                    if !sessionManager.isTimerExpired {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .frame(width: 280, height: 280)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: progress)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 280, height: 280)
                    }
                    
                    // Timer text
                    VStack(spacing: 8) {
                        if sessionManager.isTimerExpired {
                            Text("TIME'S UP!")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Text(formatTime(sessionManager.restTimeRemaining))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal)
                } else if let exercise = sessionManager.currentExercise {
                    // Show set info for rest timer (not transition)
                    VStack(spacing: 8) {
                        Text(exercise.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        if let targetSets = exercise.targetSets {
                            Text("Next set \(sessionManager.currentSetNumber)/\(targetSets)")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        
                        if let target = getTargetString(for: exercise) {
                            Text(target)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Status text
                if sessionManager.isTimerExpired {
                    VStack(spacing: 12) {
                        Text(sessionManager.transitionToExercise != nil ? "Ready to Go!" : "Time to Work!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(sessionManager.transitionToExercise != nil ? "The transition is over" : "Rest period is complete")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                } else {
                    Text(sessionManager.transitionToExercise != nil ? "Get Ready!" : "Rest in progress")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                
                // Action button
                Button(action: {
                    sessionManager.toggleTimer()
                    dismiss()
                }) {
                    Text(sessionManager.transitionToExercise != nil ? "Start Exercise" : "Continue Workout")
                        .font(.headline)
                        .fontWeight(.semibold)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: WorkoutTimelineView(sessionManager: sessionManager)) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var progress: CGFloat {
        CGFloat(sessionManager.restTimeRemaining / sessionManager.restTimerDuration)
    }
    
    private var timerColor: Color {
        if sessionManager.restTimeRemaining <= 0 {
            return .red
        }
        return sessionManager.transitionToExercise != nil ? .blue : .orange
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
                parts.append("@ \(String(format: "%.1f", weight))kg")
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
