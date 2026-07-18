//
//  DebugTestSupport.swift
//  gym-bro
//
//  DEBUG-only support for automated testing of the workout-history-editing,
//  in-workout set-editing and progression-suggestion features.
//
//  Activated via launch arguments (see GymBroApp):
//    --run-logic-tests   Runs DebugLogicTests against the production
//                        persistence / engine functions and writes a
//                        PASS/FAIL report to Documents/logic-test-results.txt
//    --seed-test-data    Seeds the live model container with deterministic
//                        data (splits, exercises, historical sessions incl.
//                        one that fires the progression trigger) for manual /
//                        screenshot-driven UI testing.
//
//  Everything here is wrapped in #if DEBUG so it can safely stay in the repo
//  and is stripped from release builds.
//

#if DEBUG
import Foundation
import SwiftData

enum DebugTestFlags {
    static var runLogicTests: Bool { CommandLine.arguments.contains("--run-logic-tests") }
    static var seedTestData: Bool { CommandLine.arguments.contains("--seed-test-data") }
    /// Wipes the persistent store before seeding so automated UI tests get a
    /// deterministic starting point on every launch (the store is otherwise
    /// persisted between launches and mutated by the tests themselves).
    static var resetStore: Bool { CommandLine.arguments.contains("--uitest-reset") }
}

// MARK: - Logic Tests

@MainActor
enum DebugLogicTests {

    private static var report: [String] = []
    private static var passCount = 0
    private static var failCount = 0
    private static var knownIssueCount = 0

    private static func check(_ name: String, _ condition: Bool, _ detail: String = "") {
        if condition {
            passCount += 1
            log("PASS  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        } else {
            failCount += 1
            log("FAIL  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        }
    }

    /// Characterization assert: pins down *currently accepted but questionable*
    /// behaviour. A satisfied condition is reported as KNOWN-ISSUE (not PASS)
    /// and counted separately so the summary never claims this is desired.
    /// A violated condition is still a hard FAIL (the characterization drifted).
    private static func checkKnownIssue(_ name: String, _ condition: Bool, _ detail: String = "") {
        if condition {
            knownIssueCount += 1
            log("KNOWN-ISSUE (characterization)  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        } else {
            failCount += 1
            log("FAIL  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        }
    }

    private static func log(_ line: String) {
        report.append(line)
        print("LOGICTEST \(line)")
    }

    static func run(context: ModelContext) {
        report.removeAll(); passCount = 0; failCount = 0; knownIssueCount = 0
        log("==== gym-bro logic tests ====")

        testProgressionTrigger_C(context)
        testProgressionFiresDuringActiveSession_Suspicion1(context)
        testCurrentSetNumberAfterDelete_Suspicion2(context)
        testWeightRatioEmptySessions_Suspicion3(context)
        testIncreaseReminderUsesRealSessions_Fix1(context)
        testSetTimeReorderNoWrongSkip_Suspicion4(context)
        testOutOfRangeSetTime_Suspicion5(context)
        testPersonalRecordRecompute_Suspicion6(context)
        testAddEditDeleteRoundTrip_FlowA(context)

        log("==== summary: \(passCount) passed, \(knownIssueCount) known-issue, \(failCount) failed ====")
        writeReport()
    }

    private static func writeReport() {
        let text = report.joined(separator: "\n") + "\n"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = dir.appendingPathComponent("logic-test-results.txt")
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: helpers

    private static func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    // MARK: - Suspicion C / progression trigger

    private static func testProgressionTrigger_C(_ context: ModelContext) {
        let ctx = context
        let location = GymLocation(name: "Test Gym", sortOrder: 0)
        let exercise = Exercise(name: "Chest Press", targetWeight: 30, targetSets: 4, minReps: 8, maxReps: 12)
        ctx.insert(location); ctx.insert(exercise)

        let plan: [(Int, Int)] = [(-21, 10), (-14, 13), (-7, 14), (-1, 12)]
        for (days, reps) in plan {
            let base = day(days)
            let session = WorkoutSession(startTime: base, endTime: base.addingTimeInterval(3600), gymLocation: location)
            ctx.insert(session)
            for i in 0..<4 {
                let s = WorkoutSet(startTime: base.addingTimeInterval(Double(i) * 300), weight: 30, reps: reps,
                                   exercise: exercise, session: session)
                ctx.insert(s)
            }
        }

        guard let suggestion = ProgressionEngine.evaluate(exercise: exercise, at: location) else {
            check("C.progression evaluate returns a suggestion", false); return
        }
        check("C.progression suggestsIncrease", suggestion.suggestsIncrease,
              "triggers=\(suggestion.triggers.map { $0.title })")
        check("C.progression suggestedWeight > target (30)", suggestion.suggestedWeight > 30,
              "suggested=\(suggestion.suggestedWeight)")
        // weightStep = 1.0 -> must be integral
        check("C.progression suggestedWeight rounded to 1kg",
              suggestion.suggestedWeight.truncatingRemainder(dividingBy: 1) == 0,
              "suggested=\(suggestion.suggestedWeight)")
        check("C.progression suggestedWeight == 35", suggestion.suggestedWeight == 35,
              "suggested=\(suggestion.suggestedWeight)")
    }

    // MARK: - Suspicion 1: banner fires during the very session that satisfies it

    private static func testProgressionFiresDuringActiveSession_Suspicion1(_ context: ModelContext) {
        let ctx = context
        let location = GymLocation(name: "Test Gym", sortOrder: 0)
        // Exercise whose only history is the CURRENTLY ACTIVE (unfinished) session.
        let exercise = Exercise(name: "Row", targetWeight: 40, targetSets: 3, minReps: 6, maxReps: 10)
        ctx.insert(location); ctx.insert(exercise)

        // Active session: endTime == nil, all target sets at max reps >= target.
        let active = WorkoutSession(startTime: Date(), endTime: nil, gymLocation: location)
        ctx.insert(active)
        for i in 0..<3 {
            let s = WorkoutSet(startTime: Date().addingTimeInterval(Double(i) * 120), weight: 40, reps: 10,
                               exercise: exercise, session: active)
            ctx.insert(s)
        }

        let suggestion = ProgressionEngine.evaluate(exercise: exercise, at: location)
        let fires = suggestion?.suggestsIncrease ?? false
        // KNOWN ISSUE: the progression banner fires during the very session that
        // satisfies it, because ProgressionEngine's history includes the active
        // (unfinished) session. Pinned as characterization, not endorsed.
        checkKnownIssue("1.progression fires mid-session (questionable: counts active session)", fires,
                        "fires=\(fires); detail=\(suggestion?.triggers.first?.detail ?? "nil")")
    }

    // MARK: - Suspicion 2: currentSetNumber desync after deleting a set mid-workout

    private static func testCurrentSetNumberAfterDelete_Suspicion2(_ context: ModelContext) {
        let ctx = context
        let exercise = Exercise(name: "Squat", targetWeight: 60, targetSets: 3, minReps: 5, maxReps: 8)
        let split = Split(name: "Legs")
        split.exercises = [exercise]
        ctx.insert(exercise); ctx.insert(split)

        let session = WorkoutSession(startTime: Date(), split: split)
        ctx.insert(session)
        var sets: [WorkoutSet] = []
        for i in 0..<3 {
            let s = WorkoutSet(startTime: Date().addingTimeInterval(Double(i) * 120), weight: 60, reps: 6,
                               exercise: exercise, session: session)
            ctx.insert(s); sets.append(s)
            session.sets = (session.sets ?? []) + [s]
        }

        let sm = SessionManager()
        sm.currentSplit = split
        sm.activeSession = session
        sm.currentExerciseIndex = 0

        check("2.currentSetNumber == 4 after 3 logged sets", sm.currentSetNumber == 4,
              "value=\(sm.currentSetNumber)")

        // Delete one set via production API (context menu path).
        WorkoutPersistence.deleteSet(sets[2], in: ctx)
        check("2.currentSetNumber == 3 after deleting one set", sm.currentSetNumber == 3,
              "value=\(sm.currentSetNumber)")

        WorkoutPersistence.deleteSet(sets[1], in: ctx)
        check("2.currentSetNumber == 2 after deleting two sets", sm.currentSetNumber == 2,
              "value=\(sm.currentSetNumber)")
        // No stored counter -> derived value tracks deletions, no off-by-one desync.
    }

    // MARK: - Suspicion 3: WeightRatioEngine called with allSessions: []

    private static func testWeightRatioEmptySessions_Suspicion3(_ context: ModelContext) {
        let ctx = context
        let source = GymLocation(name: "Home", sortOrder: 0)
        let target = GymLocation(name: "Studio", sortOrder: 1)
        let exercise = Exercise(name: "Bench", targetWeight: 50, targetSets: 3, minReps: 6, maxReps: 10)
        ctx.insert(source); ctx.insert(target); ctx.insert(exercise)

        // Characterizes the degenerate empty-input path. This is the behaviour
        // increaseReminderBanner USED to hit when it passed `allSessions: []`
        // (now fixed — see Fix 1 / testIncreaseReminderUsesRealSessions_Fix1):
        // with no history the engine can only return the 1:1 "No data" fallback.
        let empty = WeightRatioEngine.suggestWeight(for: exercise, from: source, to: target,
                                                    newSourceWeight: 32, allSessions: [])
        checkKnownIssue("3.empty allSessions -> confidence .none (degenerate call, fixed in view)",
                        empty.confidence == .none,
                        "confidence=\(empty.confidence.label), dataPoints=\(empty.dataPoints)")
        checkKnownIssue("3.empty allSessions -> 1:1 fallback (ratio nil)", empty.ratio == nil,
                        "suggested=\(empty.suggestedWeight)")

        // Prove the engine COULD compute a real ratio if it were given the sessions.
        let sSess = WorkoutSession(startTime: day(-2), gymLocation: source)
        sSess.gymLocationId = source.id
        let sSet = WorkoutSet(startTime: day(-2), weight: 40, reps: 8, exercise: exercise, session: sSess)
        let tSess = WorkoutSession(startTime: day(-1), gymLocation: target)
        tSess.gymLocationId = target.id
        let tSet = WorkoutSet(startTime: day(-1), weight: 30, reps: 8, exercise: exercise, session: tSess)
        ctx.insert(sSess); ctx.insert(tSess); ctx.insert(sSet); ctx.insert(tSet)
        sSess.sets = [sSet]; tSess.sets = [tSet]

        let real = WeightRatioEngine.suggestWeight(for: exercise, from: source, to: target,
                                                   newSourceWeight: 40, allSessions: [sSess, tSess])
        check("3.with sessions -> ratio computed (~0.75)", real.ratio != nil && abs((real.ratio ?? 0) - 0.75) < 0.05,
              "ratio=\(String(describing: real.ratio)), suggested=\(real.suggestedWeight), conf=\(real.confidence.label)")
        // Conclusion: passing real sessions yields a location ratio; the old
        // `allSessions: []` call site was the bug, now fixed in ActiveSessionView.
    }

    // MARK: - Fix 1: increaseReminderBanner now feeds real sessions to the engine

    /// Verifies the wiring behind Fix 1: given the same source/target history,
    /// the engine returns a location-ratio suggestion when handed the real
    /// session list (as the banner now does) but degrades to the 1:1 "No data"
    /// fallback when handed `[]` (the old call site). This is the assertion that
    /// the banner's suggestion is genuinely ratio-based, not a passthrough.
    private static func testIncreaseReminderUsesRealSessions_Fix1(_ context: ModelContext) {
        let ctx = context
        let source = GymLocation(name: "Fix1 Home", sortOrder: 0)
        let target = GymLocation(name: "Fix1 Studio", sortOrder: 1)
        let exercise = Exercise(name: "Fix1 Bench", targetWeight: 50, targetSets: 3, minReps: 6, maxReps: 10)
        ctx.insert(source); ctx.insert(target); ctx.insert(exercise)

        // Time-close pair at the two locations: source 40kg, target 30kg -> 0.75.
        let sSess = WorkoutSession(startTime: day(-2), gymLocation: source)
        sSess.gymLocationId = source.id
        let sSet = WorkoutSet(startTime: day(-2), weight: 40, reps: 8, exercise: exercise, session: sSess)
        let tSess = WorkoutSession(startTime: day(-1), gymLocation: target)
        tSess.gymLocationId = target.id
        let tSet = WorkoutSet(startTime: day(-1), weight: 30, reps: 8, exercise: exercise, session: tSess)
        ctx.insert(sSess); ctx.insert(tSess); ctx.insert(sSet); ctx.insert(tSet)
        sSess.sets = [sSet]; tSess.sets = [tSet]

        // The @Query in ActiveSessionView returns all sessions; simulate that.
        let allSessions = (try? ctx.fetch(FetchDescriptor<WorkoutSession>())) ?? [sSess, tSess]

        let wired = WeightRatioEngine.suggestWeight(for: exercise, from: source, to: target,
                                                    newSourceWeight: 40, allSessions: allSessions)
        check("Fix1.banner suggestion is ratio-based (not nil)", wired.ratio != nil,
              "ratio=\(String(describing: wired.ratio)), conf=\(wired.confidence.label)")
        check("Fix1.banner ratio ~0.75 from cross-gym history",
              abs((wired.ratio ?? 0) - 0.75) < 0.05,
              "ratio=\(String(describing: wired.ratio))")
        check("Fix1.banner suggestion != source weight (adjusted down)",
              wired.suggestedWeight < 40,
              "suggested=\(wired.suggestedWeight)")
        check("Fix1.banner confidence not .none with real sessions",
              wired.confidence != .none, "conf=\(wired.confidence.label)")

        // Contrast: the pre-fix `[]` call site could only ever return the fallback.
        let fallback = WeightRatioEngine.suggestWeight(for: exercise, from: source, to: target,
                                                       newSourceWeight: 40, allSessions: [])
        check("Fix1.empty call site degrades to fallback (proves the fix matters)",
              fallback.ratio == nil && fallback.suggestedWeight == 40,
              "suggested=\(fallback.suggestedWeight)")
    }

    // MARK: - Suspicion 4: editing a set's time must not wrongly mark exercise skipped

    private static func testSetTimeReorderNoWrongSkip_Suspicion4(_ context: ModelContext) {
        let ctx = context
        let a = Exercise(name: "A-lift", targetWeight: 20, targetSets: 2, minReps: 8, maxReps: 12)
        let b = Exercise(name: "B-lift", targetWeight: 20, targetSets: 2, minReps: 8, maxReps: 12)
        let split = Split(name: "Full")
        split.exercises = [a, b]
        ctx.insert(a); ctx.insert(b); ctx.insert(split)

        let base = Date()
        let session = WorkoutSession(startTime: base, endTime: base.addingTimeInterval(3600), split: split)
        ctx.insert(session)
        // A performed first, then B.
        let a1 = WorkoutSet(startTime: base.addingTimeInterval(0), weight: 20, reps: 10, exercise: a, session: session)
        let a2 = WorkoutSet(startTime: base.addingTimeInterval(60), weight: 20, reps: 10, exercise: a, session: session)
        let b1 = WorkoutSet(startTime: base.addingTimeInterval(600), weight: 20, reps: 10, exercise: b, session: session)
        let b2 = WorkoutSet(startTime: base.addingTimeInterval(660), weight: 20, reps: 10, exercise: b, session: session)
        [a1, a2, b1, b2].forEach { ctx.insert($0) }
        session.sets = [a1, a2, b1, b2]
        WorkoutPersistence.recomputeDerivedState(for: session, split: split, in: ctx)

        check("4.initial order = [A,B]", session.actualExerciseOrder == [a.id, b.id],
              "order=\(session.actualExerciseOrder ?? [])")
        check("4.initial skipped nil", session.skippedExerciseIds == nil,
              "skipped=\(session.skippedExerciseIds ?? [])")

        // Move A's sets to AFTER B (out-of-order edit through production API).
        WorkoutPersistence.updateSet(a1, weight: 20, reps: 10, duration: nil,
                                     startTime: base.addingTimeInterval(1200), in: ctx)
        WorkoutPersistence.updateSet(a2, weight: 20, reps: 10, duration: nil,
                                     startTime: base.addingTimeInterval(1260), in: ctx)

        check("4.order becomes [B,A] after retiming", session.actualExerciseOrder == [b.id, a.id],
              "order=\(session.actualExerciseOrder ?? [])")
        check("4.neither exercise wrongly skipped", session.skippedExerciseIds == nil,
              "skipped=\(session.skippedExerciseIds ?? [])")
    }

    // MARK: - Suspicion 5: out-of-range set time saved anyway

    private static func testOutOfRangeSetTime_Suspicion5(_ context: ModelContext) {
        let ctx = context
        let ex = Exercise(name: "OOR", targetWeight: 20, targetSets: 3, minReps: 8, maxReps: 12)
        let split = Split(name: "S"); split.exercises = [ex]
        ctx.insert(ex); ctx.insert(split)

        let base = Date()
        let session = WorkoutSession(startTime: base, endTime: base.addingTimeInterval(3600), split: split)
        ctx.insert(session)
        let s1 = WorkoutSet(startTime: base.addingTimeInterval(60), weight: 20, reps: 10, exercise: ex, session: session)
        ctx.insert(s1); session.sets = [s1]
        WorkoutPersistence.recomputeDerivedState(for: session, split: split, in: ctx)

        let endBefore = session.endTime

        // Add a set with a time BEFORE the session start (out of range, only a warning in UI).
        let added = WorkoutPersistence.addSet(exercise: ex, session: session, weight: 25, reps: 9, duration: nil,
                                              startTime: base.addingTimeInterval(-1800), in: ctx)
        // KNOWN ISSUE: an out-of-range set time (before session start) is only
        // soft-warned in the UI and still persists here. Pinned, not endorsed.
        checkKnownIssue("5.out-of-range set is persisted (only a UI warning, not blocked)",
                        session.sets?.contains(where: { $0 === added }) ?? false)
        check("5.session.endTime unchanged by set edit", session.endTime == endBefore)
        check("5.exercise still performed (not skipped)", session.skippedExerciseIds == nil,
              "skipped=\(session.skippedExerciseIds ?? [])")
        // Ordering: earliest startTime should come first via getOrdered-style sort.
        let ordered = (session.sets ?? []).sorted { $0.startTime < $1.startTime }
        check("5.out-of-range set sorts first (cosmetic ordering only)", ordered.first?.id == added.id)
    }

    // MARK: - Suspicion 6: PR recompute after add/edit (no false positive)

    private static func testPersonalRecordRecompute_Suspicion6(_ context: ModelContext) {
        let ctx = context
        let ex = Exercise(name: "PR-lift", targetWeight: 50, targetSets: 3, minReps: 6, maxReps: 10)
        ctx.insert(ex)

        // Historical session with volume 500 (50 x 10).
        let hist = WorkoutSession(startTime: day(-7))
        ctx.insert(hist)
        let hSet = WorkoutSet(startTime: day(-7), weight: 50, reps: 10, exercise: ex, session: hist)
        ctx.insert(hSet); hist.sets = [hSet]

        // Current session with volume 400 (40 x 10) -> NOT a PR.
        let cur = WorkoutSession(startTime: day(0))
        ctx.insert(cur)
        let cSet = WorkoutSet(startTime: day(0), weight: 40, reps: 10, exercise: ex, session: cur)
        ctx.insert(cSet); cur.sets = [cSet]

        func isPR(session: WorkoutSession, allSessions: [WorkoutSession]) -> Bool {
            // Mirrors WorkoutHistoryDetailView.personalRecords algorithm.
            let sessionMax = (session.sets ?? []).compactMap { s -> Double? in
                guard let w = s.weight, let r = s.reps else { return nil }
                return w * Double(r)
            }.max() ?? 0
            let hMax = allSessions.filter { $0.id != session.id }
                .flatMap { $0.sets ?? [] }
                .filter { $0.exercise?.id == ex.id }
                .compactMap { s -> Double? in
                    guard let w = s.weight, let r = s.reps else { return nil }
                    return w * Double(r)
                }.max() ?? 0
            return sessionMax > hMax
        }

        let all = [hist, cur]
        check("6.no false-positive PR before edit (400 < 500)", isPR(session: cur, allSessions: all) == false)

        // Edit current set up to 60 x 10 (volume 600) -> should become a PR after recompute.
        WorkoutPersistence.updateSet(cSet, weight: 60, reps: 10, duration: nil, startTime: day(0), in: ctx)
        check("6.PR recomputed true after edit (600 > 500)", isPR(session: cur, allSessions: all) == true)
    }

    // MARK: - Flow A: add / edit / delete / removeExercise round trip

    private static func testAddEditDeleteRoundTrip_FlowA(_ context: ModelContext) {
        let ctx = context
        let ex = Exercise(name: "Flow", targetWeight: 20, targetSets: 3, minReps: 8, maxReps: 12)
        let split = Split(name: "S"); split.exercises = [ex]
        ctx.insert(ex); ctx.insert(split)
        let base = Date()
        let session = WorkoutSession(startTime: base, endTime: base.addingTimeInterval(3600), split: split)
        ctx.insert(session)

        let added = WorkoutPersistence.addSet(exercise: ex, session: session, weight: 20, reps: 10, duration: nil,
                                              startTime: base.addingTimeInterval(60), in: ctx)
        check("A.addSet -> 1 set, exercise performed", (session.sets?.count == 1) && session.skippedExerciseIds == nil)
        check("A.addSet -> appended to exercise.history", ex.history?.contains(where: { $0.id == added.id }) ?? false)

        WorkoutPersistence.updateSet(added, weight: 22.5, reps: 11, duration: nil,
                                     startTime: base.addingTimeInterval(120), in: ctx)
        check("A.updateSet -> values persisted", added.weight == 22.5 && added.reps == 11)

        // Deleting the only set of the exercise -> exercise becomes skipped
        // AND is dropped from actualExerciseOrder (regression: stale session.sets).
        WorkoutPersistence.deleteSet(added, in: ctx)
        check("A.deleteSet last set -> exercise counted as skipped",
              session.skippedExerciseIds == [ex.id],
              "skipped=\(session.skippedExerciseIds ?? [])")
        check("A.deleteSet last set -> exercise dropped from order",
              (session.actualExerciseOrder ?? []).isEmpty,
              "order=\(session.actualExerciseOrder ?? [])")

        // Re-add then removeExercise.
        let s2 = WorkoutPersistence.addSet(exercise: ex, session: session, weight: 20, reps: 10, duration: nil,
                                           startTime: base.addingTimeInterval(60), in: ctx)
        _ = s2
        WorkoutPersistence.removeExercise(ex, from: session, in: ctx)
        check("A.removeExercise -> all sets gone & skipped",
              (session.sets?.isEmpty ?? true) && session.skippedExerciseIds == [ex.id],
              "sets=\(session.sets?.count ?? 0), skipped=\(session.skippedExerciseIds ?? [])")
    }
}

// MARK: - Seed data for manual / screenshot UI testing

@MainActor
enum DebugSeed {
    /// Deletes every persisted object so a subsequent seed starts from scratch.
    /// Used by the UI-test harness via the `--uitest-reset` launch argument.
    static func reset(_ context: ModelContext) {
        try? context.delete(model: WorkoutSet.self)
        try? context.delete(model: WorkoutSession.self)
        try? context.delete(model: ExerciseLocationProfile.self)
        try? context.delete(model: Exercise.self)
        try? context.delete(model: Split.self)
        try? context.delete(model: ExerciseCategory.self)
        try? context.delete(model: GymLocation.self)
        try? context.save()
    }

    static func seed(into context: ModelContext) {
        // Avoid double-seeding.
        let existing = try? context.fetch(FetchDescriptor<Split>())
        if let existing, !existing.isEmpty { return }

        let location = GymLocation(name: "Downtown Gym", sortOrder: 0)
        context.insert(location)

        let chest = Exercise(name: "Chest Press", notes: "Squeeze chest",
                             targetWeight: 30, targetSets: 4, minReps: 8, maxReps: 12)
        let row = Exercise(name: "Seated Row", targetWeight: 45, targetSets: 3, minReps: 8, maxReps: 12)
        let curl = Exercise(name: "Bicep Curl", targetWeight: 15, targetSets: 3, minReps: 10, maxReps: 15)
        let plank = Exercise(name: "Plank") // duration based, no target
        [chest, row, curl, plank].forEach { context.insert($0) }

        let split = Split(name: "Upper Body")
        split.exercises = [chest, row, curl, plank]
        context.insert(split)

        // Historical sessions. Chest Press progresses so the newest session fires
        // the progression trigger (all 4 sets at 30 kg x 12 = top of range).
        let plan: [(days: Int, chestReps: Int)] = [(-21, 10), (-14, 13), (-7, 14), (-2, 12)]
        for entry in plan {
            let baseDate = Calendar.current.date(byAdding: .day, value: entry.days, to: Date())!
            let session = WorkoutSession(startTime: baseDate,
                                         endTime: baseDate.addingTimeInterval(3300),
                                         split: split,
                                         gymLocation: location)
            context.insert(session)
            var sets: [WorkoutSet] = []

            for i in 0..<4 {
                let s = WorkoutSet(startTime: baseDate.addingTimeInterval(Double(i) * 300),
                                   weight: 30, reps: entry.chestReps, exercise: chest, session: session,
                                   endTime: baseDate.addingTimeInterval(Double(i) * 300 + 45),
                                   restDuration: 120, restTimerUsed: true)
                context.insert(s); sets.append(s)
            }
            for i in 0..<3 {
                let s = WorkoutSet(startTime: baseDate.addingTimeInterval(1800 + Double(i) * 300),
                                   weight: 45, reps: 10, exercise: row, session: session,
                                   endTime: baseDate.addingTimeInterval(1800 + Double(i) * 300 + 45),
                                   restDuration: 90, restTimerUsed: true)
                context.insert(s); sets.append(s)
            }
            for i in 0..<3 {
                let s = WorkoutSet(startTime: baseDate.addingTimeInterval(2700 + Double(i) * 200),
                                   weight: 15, reps: 12, exercise: curl, session: session,
                                   endTime: baseDate.addingTimeInterval(2700 + Double(i) * 200 + 30),
                                   restDuration: 60, restTimerUsed: false)
                context.insert(s); sets.append(s)
            }
            session.sets = sets
            WorkoutPersistence.recomputeDerivedState(for: session, split: split, in: context)
        }

        try? context.save()
    }
}
#endif
