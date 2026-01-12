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
                        
                        Text("Rest Timer")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Status text
                Text(sessionManager.restTimeRemaining > 0 ? "Rest in progress" : "Rest complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                // Dismiss button
                Button(action: {
                    sessionManager.toggleTimer()
                    dismiss()
                }) {
                    Text("Continue Workout")
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
        sessionManager.restTimeRemaining > 0 ? .green : .red
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    let manager = SessionManager()
    manager.restTimeRemaining = 90
    manager.isRestTimerActive = true
    return RestTimerView(sessionManager: manager)
}
