//
//  RestTimerView.swift
//  gym-bro
//
//  Created by Moritz Goessl on 12.01.26.
//

import SwiftUI

struct RestTimerView: View {
    var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var skipTrigger = false

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                timerCircle

                exerciseInfoSection
                    .padding(.top, Theme.Spacing.xxxl)

                Spacer()

                statusMessage
                    .padding(.bottom, Theme.Spacing.xl)

                continueButton
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
        .sensoryFeedback(.success, trigger: sessionManager.isTimerExpired)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: timerGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 1.0), value: sessionManager.isTimerExpired)
    }

    private var timerGradientColors: [Color] {
        if sessionManager.isTimerExpired {
            return [.red.opacity(0.8), .red]
        }
        if sessionManager.transitionToExercise != nil {
            return [.blue.opacity(0.7), .blue]
        }
        return [.orange.opacity(0.7), .orange]
    }

    // MARK: - Timer Circle

    private var timerCircle: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 16)
                .frame(width: 260, height: 260)

            // Progress or expired fill
            if sessionManager.isTimerExpired {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 260, height: 260)
                    .phaseAnimator([false, true]) { content, phase in
                        content.opacity(phase ? 0.3 : 0.15)
                    } animation: { _ in
                        .easeInOut(duration: 1.0)
                    }
            } else {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
            }

            // Time display
            VStack(spacing: Theme.Spacing.sm) {
                if sessionManager.isTimerExpired {
                    Text("TIME'S UP!")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                } else {
                    Text(formatTime(sessionManager.restTimeRemaining))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Text(sessionManager.transitionToExercise != nil ? "Next Up" : "Rest Timer")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Exercise Info

    private var exerciseInfoSection: some View {
        Group {
            if let transitionExercise = sessionManager.transitionToExercise {
                transitionExerciseDetails(transitionExercise)
            } else if let exercise = sessionManager.currentExercise {
                restExerciseDetails(exercise)
            }
        }
    }

    private func transitionExerciseDetails(_ exercise: Exercise) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(exercise.name)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let target = exercise.targetString(for: sessionManager.currentLocation) {
                Text(target)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            if let notes = exercise.notes {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
    }

    private func restExerciseDetails(_ exercise: Exercise) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(exercise.name)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let targetSets = exercise.targetSets {
                Text("Next set \(sessionManager.currentSetNumber)/\(targetSets)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.numericText())
            }

            if let target = exercise.targetString(for: sessionManager.currentLocation) {
                Text(target)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Status Message

    private var statusMessage: some View {
        Group {
            if sessionManager.isTimerExpired {
                VStack(spacing: Theme.Spacing.sm) {
                    Text(sessionManager.transitionToExercise != nil ? "Ready to Go!" : "Time to Work!")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(sessionManager.transitionToExercise != nil ? "The transition is over" : "Rest period is complete")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Text(sessionManager.transitionToExercise != nil ? "Get Ready!" : "Rest in progress")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: {
            skipTrigger.toggle()
            sessionManager.toggleTimer()
            dismiss()
        }) {
            Text(sessionManager.transitionToExercise != nil ? "Start Exercise" : "Continue Workout")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(timerColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Theme.TouchTarget.large)
                .background(.white, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: skipTrigger)
    }

    // MARK: - Computed Properties

    private var progress: CGFloat {
        guard sessionManager.restTimerDuration > 0 else { return 0 }
        return CGFloat(sessionManager.restTimeRemaining / sessionManager.restTimerDuration)
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
}

#Preview {
    let manager = SessionManager()
    return RestTimerView(sessionManager: manager)
}
