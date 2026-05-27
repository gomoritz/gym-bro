//
//  StatisticsView.swift
//  gym-bro
//
//  Created by Claude Code
//

import Charts
import SwiftData
import SwiftUI

// MARK: - Scope

enum StatsScope: String, CaseIterable, Identifiable {
    case global
    case exercise

    var id: String { rawValue }

    var label: String {
        switch self {
        case .global: return "Global"
        case .exercise: return "Exercise"
        }
    }
}

// MARK: - Time Range

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .year: return "1 Year"
        case .all: return "All Time"
        }
    }

    func cutoffDate(now: Date = .now) -> Date? {
        let cal = Calendar.current
        switch self {
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: now)
        case .year: return cal.date(byAdding: .year, value: -1, to: now)
        case .all: return nil
        }
    }
}

// MARK: - Shared Helpers

enum StatsFormat {
    static func tonnage(_ kg: Double) -> String {
        if kg >= 1_000 {
            return String(format: "%.1f t", kg / 1_000)
        }
        return String(format: "%.0f kg", kg)
    }

    static func tonnageAxis(_ tonnes: Double) -> String {
        if tonnes >= 1 {
            return String(format: "%.0ft", tonnes)
        }
        return String(format: "%.0fkg", tonnes * 1_000)
    }

    static func minutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    static func weight(_ kg: Double) -> String {
        if kg.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f kg", kg)
        }
        return String(format: "%.1f kg", kg)
    }

    static func seconds(_ seconds: Double) -> String {
        if seconds >= 60 {
            let m = Int(seconds) / 60
            let s = Int(seconds) % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return String(format: "%.0fs", seconds)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            content
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

struct StatsNoDataView: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Not enough data yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xl)
    }
}

// MARK: - Orchestrator

struct StatisticsView: View {
    @Query private var sessions: [WorkoutSession]
    @State private var scope: StatsScope = .global
    @State private var timeRange: StatsTimeRange = .threeMonths

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Scope", selection: $scope) {
                    ForEach(StatsScope.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, Theme.Spacing.sm)

                Group {
                    switch scope {
                    case .global:
                        GlobalStatisticsView(timeRange: $timeRange)
                    case .exercise:
                        ExerciseStatisticsView(timeRange: $timeRange)
                    }
                }
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !sessions.isEmpty {
                        timeRangeMenu
                    }
                }
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

// MARK: - Global Statistics

struct GlobalStatisticsView: View {
    @Binding var timeRange: StatsTimeRange
    @Query(sort: \WorkoutSession.startTime, order: .forward)
    private var sessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            if sessions.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xxxl * 2)
            } else {
                VStack(spacing: Theme.Spacing.xxl) {
                    overviewSection
                    frequencyHeatmapSection
                    weeklyVolumeSection
                    durationTrendSection
                    dayHourHeatmapSection
                }
                .padding()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 70))
                .foregroundStyle(.tertiary)

            Text("No Stats Yet")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Text("Finish a workout to see analytics here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Filtered Data

    private var filteredSessions: [WorkoutSession] {
        guard let cutoff = timeRange.cutoffDate() else { return sessions }
        return sessions.filter { $0.startTime >= cutoff }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        let workoutCount = filteredSessions.count
        let volume = totalVolume(filteredSessions)
        let avgDuration = averageDurationMinutes(filteredSessions)
        let perWeek = sessionsPerWeek

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.lg), GridItem(.flexible())],
            spacing: Theme.Spacing.lg
        ) {
            StatCard(
                title: "Workouts",
                value: "\(workoutCount)",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )
            StatCard(
                title: "Volume",
                value: StatsFormat.tonnage(volume),
                icon: "scalemass.fill",
                color: Theme.Colors.volume
            )
            StatCard(
                title: "Avg Duration",
                value: avgDuration.map(StatsFormat.minutes) ?? "—",
                icon: "clock.fill",
                color: .orange
            )
            StatCard(
                title: "Per Week",
                value: String(format: "%.1f", perWeek),
                icon: "calendar",
                color: .green
            )
        }
    }

    private var sessionsPerWeek: Double {
        guard let earliest = filteredSessions.first?.startTime else { return 0 }
        let cutoff = timeRange.cutoffDate() ?? earliest
        let start = min(earliest, cutoff)
        let weeks = max(1.0, Date.now.timeIntervalSince(start) / (7 * 24 * 3600))
        return Double(filteredSessions.count) / weeks
    }

    // MARK: - Frequency Heatmap

    private var frequencyHeatmapSection: some View {
        ChartCard("Activity") {
            let weeks = heatmapWeeks
            let volumes = dailyVolumes(filteredSessions)
            let maxVolume = volumes.values.map { $0.volume }.max() ?? 1

            if weeks.isEmpty {
                StatsNoDataView()
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            HStack(alignment: .top, spacing: heatmapCellSpacing) {
                                weekdayLabelsColumn

                                ForEach(weeks, id: \.self) { weekStart in
                                    VStack(spacing: heatmapCellSpacing) {
                                        ForEach(0..<7, id: \.self) { dayIdx in
                                            heatmapCell(
                                                date: heatmapCalendar.date(byAdding: .day, value: dayIdx, to: weekStart) ?? weekStart,
                                                volumes: volumes,
                                                maxVolume: maxVolume
                                            )
                                        }
                                    }
                                    .id(weekStart)
                                }
                            }
                            .onAppear {
                                if let lastWeek = weeks.last {
                                    proxy.scrollTo(lastWeek, anchor: .trailing)
                                }
                            }
                        }
                    }

                    heatmapLegend
                }
            }
        }
    }

    private var heatmapCellSize: CGFloat { 13 }
    private var heatmapCellSpacing: CGFloat { 3 }

    private var weekdayLabelsColumn: some View {
        VStack(spacing: heatmapCellSpacing) {
            ForEach(0..<7, id: \.self) { idx in
                Text(idx % 2 == 0 ? Self.dayLabels[idx] : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: heatmapCellSize, alignment: .trailing)
            }
        }
    }

    private func heatmapCell(date: Date, volumes: [Date: DailyVolume], maxVolume: Double) -> some View {
        let cal = heatmapCalendar
        let today = cal.startOfDay(for: .now)
        let day = cal.startOfDay(for: date)
        let isFuture = day > today
        let data = volumes[day]
        let intensity = data.map { min(1.0, $0.volume / maxVolume) } ?? 0

        return RoundedRectangle(cornerRadius: 2)
            .fill(heatmapColor(intensity: intensity, hasWorkout: data != nil))
            .frame(width: heatmapCellSize, height: heatmapCellSize)
            .opacity(isFuture ? 0.25 : 1)
    }

    private func heatmapColor(intensity: Double, hasWorkout: Bool) -> Color {
        guard hasWorkout else { return Color.gray.opacity(0.15) }
        return Color.green.opacity(0.30 + intensity * 0.70)
    }

    private var heatmapLegend: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            ForEach([0.0, 0.30, 0.55, 0.80, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(intensity == 0 ? Color.gray.opacity(0.15) : Color.green.opacity(0.30 + intensity * 0.70))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var heatmapWeeks: [Date] {
        let cal = heatmapCalendar
        let today = cal.startOfDay(for: .now)
        let startCandidate: Date = {
            if let cutoff = timeRange.cutoffDate() { return cutoff }
            return filteredSessions.first?.startTime ?? today
        }()
        let firstWeek = startOfWeek(startCandidate)
        let currentWeek = startOfWeek(today)

        var weeks: [Date] = []
        var cursor = firstWeek
        while cursor <= currentWeek {
            weeks.append(cursor)
            guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return weeks
    }

    // MARK: - Weekly Volume

    private var weeklyVolumeSection: some View {
        ChartCard("Weekly Volume", subtitle: "by split") {
            let data = weeklyVolumeBuckets
            if data.isEmpty {
                StatsNoDataView()
            } else {
                Chart(data) { entry in
                    BarMark(
                        x: .value("Week", entry.weekStart, unit: .weekOfYear),
                        y: .value("Volume (t)", entry.volume / 1000)
                    )
                    .foregroundStyle(by: .value("Split", entry.splitName))
                    .cornerRadius(2)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(StatsFormat.tonnageAxis(v))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: weeklyVolumeXStride)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 220)
            }
        }
    }

    private var weeklyVolumeXStride: Calendar.Component {
        switch timeRange {
        case .threeMonths: return .weekOfYear
        case .sixMonths, .year, .all: return .month
        }
    }

    private struct WeekVolumeBucket: Identifiable {
        let id: String
        let weekStart: Date
        let splitName: String
        let volume: Double
    }

    private var weeklyVolumeBuckets: [WeekVolumeBucket] {
        var grouped: [Date: [String: Double]] = [:]
        for session in filteredSessions {
            let week = startOfWeek(session.startTime)
            let name = session.displaySplitName
            grouped[week, default: [:]][name, default: 0] += sessionVolume(session)
        }
        var result: [WeekVolumeBucket] = []
        for (week, splits) in grouped {
            for (split, vol) in splits where vol > 0 {
                result.append(WeekVolumeBucket(
                    id: "\(week.timeIntervalSince1970)-\(split)",
                    weekStart: week,
                    splitName: split,
                    volume: vol
                ))
            }
        }
        return result.sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: - Duration Trend

    private var durationTrendSection: some View {
        ChartCard("Workout Duration", subtitle: "with moving average") {
            let points = durationPoints
            let ma = movingAveragePoints(points: points)

            if points.isEmpty {
                StatsNoDataView()
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    durationLegend
                    Chart {
                        ForEach(points) { p in
                            PointMark(
                                x: .value("Date", p.date),
                                y: .value("Minutes", p.minutes)
                            )
                            .foregroundStyle(Color.blue.opacity(0.55))
                            .symbolSize(35)
                        }

                        ForEach(ma) { p in
                            LineMark(
                                x: .value("Date", p.date),
                                y: .value("Minutes", p.value)
                            )
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))m")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: weeklyVolumeXStride)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private var durationLegend: some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 4) {
                Circle().fill(Color.blue.opacity(0.55)).frame(width: 8, height: 8)
                Text("Session").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Rectangle().fill(Color.orange).frame(width: 14, height: 2)
                Text("Moving avg").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private struct DurationPoint: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Double
    }

    private struct MAPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var durationPoints: [DurationPoint] {
        filteredSessions.compactMap { session in
            guard let end = session.endTime else { return nil }
            let mins = end.timeIntervalSince(session.startTime) / 60.0
            guard mins > 0 else { return nil }
            return DurationPoint(date: session.startTime, minutes: mins)
        }
    }

    private func movingAveragePoints(points: [DurationPoint]) -> [MAPoint] {
        guard points.count >= 3 else { return [] }
        let window = min(7, max(3, points.count / 4))
        let half = window / 2
        var result: [MAPoint] = []
        for i in 0..<points.count {
            let lower = max(0, i - half)
            let upper = min(points.count - 1, i + half)
            let slice = points[lower...upper]
            let avg = slice.map { $0.minutes }.reduce(0, +) / Double(slice.count)
            result.append(MAPoint(date: points[i].date, value: avg))
        }
        return result
    }

    // MARK: - Day × Hour Heatmap

    private var dayHourHeatmapSection: some View {
        ChartCard("When You Train", subtitle: "day × hour") {
            let counts = dayHourCounts
            let maxCount = counts.flatMap { $0 }.max() ?? 0

            if maxCount == 0 {
                StatsNoDataView()
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    GeometryReader { geo in
                        let labelWidth: CGFloat = 28
                        let availableWidth = geo.size.width - labelWidth - 4
                        let cellWidth = availableWidth / 24
                        let cellHeight: CGFloat = 18

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 0) {
                                Color.clear.frame(width: labelWidth + 4)
                                ForEach(0..<24, id: \.self) { hour in
                                    Group {
                                        if hour % 6 == 0 {
                                            Text("\(hour)")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                                .frame(width: cellWidth, alignment: .leading)
                                        } else {
                                            Color.clear.frame(width: cellWidth)
                                        }
                                    }
                                }
                            }

                            ForEach(0..<7, id: \.self) { dayIdx in
                                HStack(spacing: 2) {
                                    Text(Self.dayLabels[dayIdx])
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .frame(width: labelWidth, alignment: .trailing)

                                    HStack(spacing: 2) {
                                        ForEach(0..<24, id: \.self) { hour in
                                            let count = counts[dayIdx][hour]
                                            let intensity = Double(count) / Double(maxCount)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(dayHourColor(count: count, intensity: intensity))
                                                .frame(width: max(cellWidth - 2, 1), height: cellHeight)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: CGFloat(8) * 20 + 4)

                    dayHourLegend(maxCount: maxCount)
                }
            }
        }
    }

    private func dayHourColor(count: Int, intensity: Double) -> Color {
        guard count > 0 else { return Color.gray.opacity(0.12) }
        return Color.blue.opacity(0.25 + intensity * 0.75)
    }

    private func dayHourLegend(maxCount: Int) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text("0").font(.system(size: 9)).foregroundStyle(.secondary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(intensity == 0 ? Color.gray.opacity(0.12) : Color.blue.opacity(0.25 + intensity * 0.75))
                    .frame(width: 10, height: 10)
            }
            Text("\(maxCount)").font(.system(size: 9)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var dayHourCounts: [[Int]] {
        var counts: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        for session in filteredSessions {
            let weekday = Self.europeanWeekday(from: session.startTime)
            let hour = Calendar.current.component(.hour, from: session.startTime)
            counts[weekday][hour] += 1
        }
        return counts
    }

    // MARK: - Aggregation

    private struct DailyVolume {
        let volume: Double
        let count: Int
    }

    private func dailyVolumes(_ sessions: [WorkoutSession]) -> [Date: DailyVolume] {
        var result: [Date: (Double, Int)] = [:]
        let cal = heatmapCalendar
        for session in sessions {
            let day = cal.startOfDay(for: session.startTime)
            let existing = result[day] ?? (0, 0)
            result[day] = (existing.0 + sessionVolume(session), existing.1 + 1)
        }
        return result.mapValues { DailyVolume(volume: $0.0, count: $0.1) }
    }

    private func sessionVolume(_ session: WorkoutSession) -> Double {
        guard let sets = session.sets else { return 0 }
        return sets.reduce(0) { acc, set in
            let w = set.weight ?? 0
            let r = Double(set.reps ?? 0)
            return acc + w * r
        }
    }

    private func totalVolume(_ sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0) { $0 + sessionVolume($1) }
    }

    private func averageDurationMinutes(_ sessions: [WorkoutSession]) -> Double? {
        let durations = sessions.compactMap { session -> Double? in
            guard let end = session.endTime else { return nil }
            let mins = end.timeIntervalSince(session.startTime) / 60.0
            return mins > 0 ? mins : nil
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    // MARK: - Calendar

    private var heatmapCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private func startOfWeek(_ date: Date) -> Date {
        let cal = heatmapCalendar
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    private static func europeanWeekday(from date: Date) -> Int {
        let raw = Calendar.current.component(.weekday, from: date)
        return (raw + 5) % 7
    }

    private static let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
}

#Preview {
    StatisticsView()
        .modelContainer(for: [
            WorkoutSession.self, WorkoutSet.self, Exercise.self, Split.self,
            GymLocation.self, ExerciseLocationProfile.self, ExerciseCategory.self,
        ])
}
