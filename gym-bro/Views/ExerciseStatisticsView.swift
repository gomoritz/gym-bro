//
//  ExerciseStatisticsView.swift
//  gym-bro
//
//  Created by Claude Code
//

import Charts
import SwiftData
import SwiftUI

struct ExerciseStatisticsView: View {
    @Binding var timeRange: StatsTimeRange

    var fixedExercise: Exercise? = nil
    var suggestionLocation: GymLocation? = nil

    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @AppStorage("selectedStatsExerciseId") private var selectedExerciseIdString: String = ""
    @State private var showPicker = false

    private var exercisesWithHistory: [Exercise] {
        exercises.filter { ($0.history?.isEmpty == false) }
    }

    private var resolvedExercise: Exercise? {
        if let fixedExercise { return fixedExercise }
        guard let uuid = UUID(uuidString: selectedExerciseIdString) else { return nil }
        return exercises.first { $0.id == uuid }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                if fixedExercise == nil {
                    exerciseSelector
                }

                if let exercise = resolvedExercise {
                    let setData = buildSetData(for: exercise)
                    let sessionData = buildSessionData(from: setData)

                    if sessionData.isEmpty {
                        noDataForExerciseView
                    } else {
                        overviewSection(setData: setData, sessionData: sessionData)
                        progressionSuggestionCard(for: exercise)
                        topWeightSection(sessionData: sessionData)
                        e1rmSection(sessionData: sessionData)
                        volumeSection(sessionData: sessionData, exercise: exercise)
                        weightRepsScatterSection(setData: setData)
                        rpeSection(sessionData: sessionData)
                        targetHitRateSection(setData: setData)
                        restDurationSection(sessionData: sessionData)
                        gymComparisonSection(sessionData: sessionData)
                    }
                } else {
                    pickExercisePromptView
                }
            }
            .padding()
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet(
                exercises: exercisesWithHistory,
                selectedIdString: $selectedExerciseIdString
            )
        }
    }

    // MARK: - Selector

    private var exerciseSelector: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    if let exercise = resolvedExercise {
                        Text(exercise.name)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                        if let category = exercise.category?.name {
                            Text(category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Select Exercise")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Tap to choose")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Prompts

    private var pickExercisePromptView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("Pick an Exercise")
                .font(.system(.title3, design: .rounded, weight: .semibold))

            Text("Choose an exercise above to explore your progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.xxxl)
        .frame(maxWidth: .infinity)
    }

    private var noDataForExerciseView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            Text("No sets in this range")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            Text("Try a longer time range")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Overview

    private func overviewSection(setData: [ExerciseSetData], sessionData: [ExerciseSessionData]) -> some View {
        let topWeight = sessionData.map { $0.topWeight }.max() ?? 0
        let topE1RM = sessionData.map { $0.topE1RM }.max() ?? 0
        let totalVolume = sessionData.reduce(0) { $0 + $1.volume }

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.lg), GridItem(.flexible())],
            spacing: Theme.Spacing.lg
        ) {
            StatCard(
                title: "Sessions",
                value: "\(sessionData.count)",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )
            StatCard(
                title: "Top Weight",
                value: StatsFormat.weight(topWeight),
                icon: "trophy.fill",
                color: .orange
            )
            StatCard(
                title: "Est. 1RM",
                value: StatsFormat.weight(topE1RM),
                icon: "bolt.fill",
                color: .yellow
            )
            StatCard(
                title: "Volume",
                value: StatsFormat.tonnage(totalVolume),
                icon: "scalemass.fill",
                color: Theme.Colors.volume
            )
        }
    }

    // MARK: - Progression Suggestion Card

    @ViewBuilder
    private func progressionSuggestionCard(for exercise: Exercise) -> some View {
        if let suggestion = ProgressionEngine.evaluate(exercise: exercise, at: suggestionLocation) {
            let basis = suggestion.basis
            if suggestion.suggestsIncrease {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                        Text("Increase suggested → ~\(ProgressionEngine.formatWeight(suggestion.suggestedWeight))")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Spacer()
                    }

                    ForEach(Array(suggestion.triggers.enumerated()), id: \.offset) { _, trigger in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: trigger.iconName)
                                .foregroundStyle(.green)
                                .font(.subheadline)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trigger.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(trigger.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    progressionBasisFooter(basis)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else if basis.sessionsConsidered > 0 {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                        Text("On track — keep at current target")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Spacer()
                    }
                    progressionBasisFooter(basis)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                notEnoughProgressionDataCard(gymScoped: basis.gymScoped)
            }
        } else if !exercise.hasTarget {
            progressionInfoCard("Set a target weight and rep range to get progression suggestions")
        } else {
            notEnoughProgressionDataCard(gymScoped: suggestionLocation != nil)
        }
    }

    @ViewBuilder
    private func progressionBasisFooter(_ basis: ProgressionBasis) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Best e1RM \(ProgressionEngine.formatWeight(basis.bestRecentE1RM)) · target implies \(ProgressionEngine.formatWeight(basis.impliedE1RM))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(progressionScopeText(basis))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func progressionScopeText(_ basis: ProgressionBasis) -> String {
        let sessionWord = basis.sessionsConsidered == 1 ? "session" : "sessions"
        if basis.gymScoped, let name = basis.locationName {
            return "\(basis.sessionsConsidered) recent \(sessionWord) at \(name)"
        }
        return "\(basis.sessionsConsidered) recent \(sessionWord), all gyms"
    }

    private func notEnoughProgressionDataCard(gymScoped: Bool) -> some View {
        progressionInfoCard(gymScoped ? "Not enough data at this gym" : "Not enough data yet")
    }

    private func progressionInfoCard(_ message: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    // MARK: - Top Weight Chart

    private func topWeightSection(sessionData: [ExerciseSessionData]) -> some View {
        ChartCard("Top Weight", subtitle: "per session, with PRs") {
            let prIds = personalRecordIds(sessionData: sessionData)
            let prData = sessionData.filter { prIds.contains($0.id) }

            Chart {
                ForEach(sessionData) { s in
                    LineMark(
                        x: .value("Date", s.date),
                        y: .value("Weight", s.topWeight)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Date", s.date),
                        y: .value("Weight", s.topWeight)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(40)
                }

                ForEach(prData) { pr in
                    PointMark(
                        x: .value("Date", pr.date),
                        y: .value("Weight", pr.topWeight)
                    )
                    .foregroundStyle(.orange)
                    .symbol(.diamond)
                    .symbolSize(140)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(StatsFormat.weight(v))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)

            HStack(spacing: Theme.Spacing.md) {
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text("Top set").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text("PR").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - e1RM Chart

    private func e1rmSection(sessionData: [ExerciseSessionData]) -> some View {
        ChartCard("Estimated 1RM", subtitle: "Epley formula") {
            Chart {
                ForEach(sessionData) { s in
                    AreaMark(
                        x: .value("Date", s.date),
                        y: .value("e1RM", s.topE1RM)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.35), Color.purple.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)

                    LineMark(
                        x: .value("Date", s.date),
                        y: .value("e1RM", s.topE1RM)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(StatsFormat.weight(v))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Volume Section

    private func volumeSection(sessionData: [ExerciseSessionData], exercise: Exercise) -> some View {
        ChartCard("Volume per Session", subtitle: targetVolume(for: exercise) != nil ? "with target" : nil) {
            let target = targetVolume(for: exercise)

            Chart {
                ForEach(sessionData) { s in
                    BarMark(
                        x: .value("Date", s.date, unit: .day),
                        y: .value("Volume", s.volume)
                    )
                    .foregroundStyle(Theme.Colors.volume.opacity(0.75))
                    .cornerRadius(2)
                }
                if let target = target {
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 4)
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(StatsFormat.tonnageAxis(v / 1000))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Weight × Reps Scatter

    private func weightRepsScatterSection(setData: [ExerciseSetData]) -> some View {
        ChartCard("Weight × Reps", subtitle: "colored by date") {
            let dates = setData.map { $0.date }
            let oldest = dates.min() ?? .now
            let newest = dates.max() ?? .now
            let totalRange = max(1.0, newest.timeIntervalSince(oldest))

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Chart {
                    ForEach(setData) { s in
                        let progress = s.date.timeIntervalSince(oldest) / totalRange
                        PointMark(
                            x: .value("Reps", s.reps),
                            y: .value("Weight", s.weight)
                        )
                        .foregroundStyle(Color.blue.opacity(0.25 + progress * 0.75))
                        .symbolSize(70)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(StatsFormat.weight(v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                            }
                        }
                    }
                }
                .frame(height: 220)

                HStack(spacing: Theme.Spacing.xs) {
                    Text("Older").font(.caption2).foregroundStyle(.secondary)
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { p in
                        Circle()
                            .fill(Color.blue.opacity(0.25 + p * 0.75))
                            .frame(width: 8, height: 8)
                    }
                    Text("Newer").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - RPE Section

    @ViewBuilder
    private func rpeSection(sessionData: [ExerciseSessionData]) -> some View {
        let withRPE = sessionData.compactMap { s -> (Date, Double)? in
            guard let rpe = s.avgRPE else { return nil }
            return (s.date, rpe)
        }

        if !withRPE.isEmpty {
            ChartCard("RPE Trend", subtitle: "avg per session") {
                Chart {
                    ForEach(withRPE.indices, id: \.self) { idx in
                        let item = withRPE[idx]
                        LineMark(
                            x: .value("Date", item.0),
                            y: .value("RPE", item.1)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", item.0),
                            y: .value("RPE", item.1)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: 1...10)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [2, 4, 6, 8, 10]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Target Hit / Failure Rate

    @ViewBuilder
    private func targetHitRateSection(setData: [ExerciseSetData]) -> some View {
        let buckets = weeklyTargetBuckets(setData: setData)
        if !buckets.isEmpty {
            ChartCard("Target vs Failure", subtitle: "sets per week") {
                Chart(buckets) { entry in
                    BarMark(
                        x: .value("Week", entry.week, unit: .weekOfYear),
                        y: .value("Sets", entry.count)
                    )
                    .foregroundStyle(by: .value("Type", entry.category))
                    .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    "Target Hit": Color.green,
                    "Below Target": Color.yellow,
                    "Failure": Color.red,
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
            }
        }
    }

    // MARK: - Rest Duration Trend

    @ViewBuilder
    private func restDurationSection(sessionData: [ExerciseSessionData]) -> some View {
        let withRest = sessionData.compactMap { s -> (Date, Double)? in
            guard let rest = s.avgRest else { return nil }
            return (s.date, rest)
        }

        if !withRest.isEmpty {
            ChartCard("Rest Between Sets", subtitle: "avg per session") {
                Chart {
                    ForEach(withRest.indices, id: \.self) { idx in
                        let item = withRest[idx]
                        LineMark(
                            x: .value("Date", item.0),
                            y: .value("Rest", item.1)
                        )
                        .foregroundStyle(.teal)
                        .interpolationMethod(.monotone)

                        PointMark(
                            x: .value("Date", item.0),
                            y: .value("Rest", item.1)
                        )
                        .foregroundStyle(.teal)
                        .symbolSize(35)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(StatsFormat.seconds(v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Gym Comparison

    @ViewBuilder
    private func gymComparisonSection(sessionData: [ExerciseSessionData]) -> some View {
        let gymStats = gymComparisonStats(sessionData: sessionData)
        let uniqueGyms = Set(sessionData.compactMap { $0.gymLocation })

        if uniqueGyms.count >= 2 {
            ChartCard("By Gym", subtitle: "top weight & average") {
                Chart(gymStats) { stat in
                    BarMark(
                        x: .value("Gym", stat.gym),
                        y: .value("Weight", stat.weight)
                    )
                    .foregroundStyle(by: .value("Metric", stat.metric))
                    .position(by: .value("Metric", stat.metric))
                    .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    "Top": Color.orange,
                    "Avg": Color.blue.opacity(0.7),
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(StatsFormat.weight(v))
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
            }
        }
    }

    // MARK: - X axis stride helper

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .threeMonths: return .weekOfYear
        case .sixMonths, .year, .all: return .month
        }
    }

    // MARK: - Data Models

    struct ExerciseSetData: Identifiable {
        let id: UUID
        let sessionId: UUID
        let date: Date
        let weight: Double
        let reps: Int
        let rpe: Int?
        let restDuration: TimeInterval?
        let wasFailure: Bool
        let targetReps: Int?
        let gymLocation: String?
    }

    struct ExerciseSessionData: Identifiable {
        let id: UUID
        let date: Date
        let topWeight: Double
        let topE1RM: Double
        let volume: Double
        let avgRPE: Double?
        let avgRest: TimeInterval?
        let setCount: Int
        let failureCount: Int
        let targetHitCount: Int
        let belowTargetCount: Int
        let gymLocation: String?
    }

    struct WeeklyTargetBucket: Identifiable {
        let id: String
        let week: Date
        let category: String
        let count: Int
    }

    struct GymStat: Identifiable {
        let id: String
        let gym: String
        let metric: String
        let weight: Double
    }

    // MARK: - Data Builders

    private func buildSetData(for exercise: Exercise) -> [ExerciseSetData] {
        let cutoff = timeRange.cutoffDate()
        let history = exercise.history ?? []
        return history.compactMap { set in
            guard let weight = set.weight, weight > 0,
                  let reps = set.reps, reps > 0,
                  let session = set.session
            else { return nil }

            let date = session.startTime
            if let cutoff = cutoff, date < cutoff { return nil }

            return ExerciseSetData(
                id: set.id,
                sessionId: session.id,
                date: date,
                weight: weight,
                reps: reps,
                rpe: set.rpe,
                restDuration: set.restDuration,
                wasFailure: set.wasFailure ?? false,
                targetReps: set.targetRepsAttempted,
                gymLocation: session.gymLocationName
            )
        }.sorted { $0.date < $1.date }
    }

    private func buildSessionData(from setData: [ExerciseSetData]) -> [ExerciseSessionData] {
        let grouped = Dictionary(grouping: setData, by: \.sessionId)
        var result: [ExerciseSessionData] = []

        for (sessionId, sets) in grouped {
            let topWeight = sets.map { $0.weight }.max() ?? 0
            let topE1RM = sets.map { epley(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            let volume = sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
            let rpes = sets.compactMap { $0.rpe }.map(Double.init)
            let avgRPE = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)
            let rests = sets.compactMap { $0.restDuration }
            let avgRest = rests.isEmpty ? nil : rests.reduce(0, +) / Double(rests.count)
            let date = sets.map { $0.date }.min() ?? .now
            let gym = sets.first?.gymLocation
            let failureCount = sets.filter { $0.wasFailure }.count
            let targetHitCount = sets.filter { set in
                guard let target = set.targetReps else { return false }
                return set.reps >= target && !set.wasFailure
            }.count
            let belowTargetCount = sets.filter { set in
                guard let target = set.targetReps else { return false }
                return set.reps < target && !set.wasFailure
            }.count

            result.append(ExerciseSessionData(
                id: sessionId,
                date: date,
                topWeight: topWeight,
                topE1RM: topE1RM,
                volume: volume,
                avgRPE: avgRPE,
                avgRest: avgRest,
                setCount: sets.count,
                failureCount: failureCount,
                targetHitCount: targetHitCount,
                belowTargetCount: belowTargetCount,
                gymLocation: gym
            ))
        }

        return result.sorted { $0.date < $1.date }
    }

    private func personalRecordIds(sessionData: [ExerciseSessionData]) -> Set<UUID> {
        var result: Set<UUID> = []
        var maxSoFar: Double = 0
        for s in sessionData {
            if s.topWeight > maxSoFar {
                result.insert(s.id)
                maxSoFar = s.topWeight
            }
        }
        return result
    }

    private func weeklyTargetBuckets(setData: [ExerciseSetData]) -> [WeeklyTargetBucket] {
        var grouped: [Date: [String: Int]] = [:]
        let cal = isoCalendar
        for s in setData {
            // Only count sets that have a target reference
            guard s.targetReps != nil else { continue }
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: s.date)
            guard let week = cal.date(from: comps) else { continue }

            let category: String
            if s.wasFailure {
                category = "Failure"
            } else if let target = s.targetReps, s.reps >= target {
                category = "Target Hit"
            } else {
                category = "Below Target"
            }

            grouped[week, default: [:]][category, default: 0] += 1
        }

        var result: [WeeklyTargetBucket] = []
        for (week, cats) in grouped {
            for (cat, count) in cats {
                result.append(WeeklyTargetBucket(
                    id: "\(week.timeIntervalSince1970)-\(cat)",
                    week: week,
                    category: cat,
                    count: count
                ))
            }
        }
        return result.sorted { $0.week < $1.week }
    }

    private func gymComparisonStats(sessionData: [ExerciseSessionData]) -> [GymStat] {
        let byGym = Dictionary(grouping: sessionData) { $0.gymLocation ?? "—" }
        var result: [GymStat] = []
        for (gym, sessions) in byGym {
            let weights = sessions.map { $0.topWeight }
            let top = weights.max() ?? 0
            let avg = weights.isEmpty ? 0 : weights.reduce(0, +) / Double(weights.count)
            result.append(GymStat(id: "\(gym)-top", gym: gym, metric: "Top", weight: top))
            result.append(GymStat(id: "\(gym)-avg", gym: gym, metric: "Avg", weight: avg))
        }
        return result.sorted { $0.gym < $1.gym }
    }

    private func targetVolume(for exercise: Exercise) -> Double? {
        guard let targetWeight = exercise.targetWeight,
              let targetSets = exercise.targetSets,
              let minReps = exercise.minReps,
              let maxReps = exercise.maxReps,
              targetWeight > 0, targetSets > 0
        else { return nil }
        let avgReps = Double(minReps + maxReps) / 2.0
        return targetWeight * Double(targetSets) * avgReps
    }

    private func epley(weight: Double, reps: Int) -> Double {
        ProgressionEngine.e1RM(weight: weight, reps: reps)
    }

    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }
}

// MARK: - Exercise Picker Sheet

private struct ExercisePickerSheet: View {
    let exercises: [Exercise]
    @Binding var selectedIdString: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return exercises }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Tracked Exercises",
                        systemImage: "dumbbell",
                        description: Text("Complete a workout set to see exercises here")
                    )
                } else {
                    List(filteredExercises) { exercise in
                        Button {
                            selectedIdString = exercise.id.uuidString
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if let category = exercise.category?.name {
                                        Text(category)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedIdString == exercise.id.uuidString {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Workout-embedded Detail Wrapper

struct ExerciseStatsDetailView: View {
    let exercise: Exercise
    var location: GymLocation? = nil
    @State private var timeRange: StatsTimeRange = .threeMonths

    var body: some View {
        ExerciseStatisticsView(
            timeRange: $timeRange,
            fixedExercise: exercise,
            suggestionLocation: location
        )
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                timeRangeMenu
            }
        }
    }

    private var timeRangeMenu: some View {
        Menu {
            Picker("Time Range", selection: $timeRange) {
                ForEach(StatsTimeRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(timeRange.rawValue)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
    }
}

#Preview {
    ExerciseStatisticsView(timeRange: .constant(.threeMonths))
        .modelContainer(for: [
            WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self,
            GymLocation.self, ExerciseLocationProfile.self, ExerciseCategory.self,
        ])
}

#Preview("Exercise Stats Detail") {
    let fixture = ProgressionPreviewData.make()
    return NavigationStack {
        ExerciseStatsDetailView(exercise: fixture.exercise, location: fixture.location)
    }
    .modelContainer(fixture.container)
}
