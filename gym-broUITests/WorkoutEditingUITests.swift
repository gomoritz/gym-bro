//
//  WorkoutEditingUITests.swift
//  gym-broUITests
//
//  End-to-end UI verification of the workout-history-editing, in-workout
//  set-editing and progression-suggestion features. Every test launches a
//  fresh, deterministically seeded app via the `--uitest-reset --seed-test-data`
//  launch arguments (see DebugTestSupport.swift / GymBroApp.swift).
//

import XCTest

final class WorkoutEditingUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Launch / navigation helpers

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--seed-test-data"]
        app.launch()
        // Reset + seed run ~0.5s after the first view appears; give the store
        // time to settle into the deterministic seeded state before poking it.
        sleep(3)
        return app
    }

    /// Opens the most recent seeded session ("Upper Body", 2 days ago) in the
    /// history detail view.
    private func openFirstHistoryDetail(_ app: XCUIApplication) {
        app.tabBars.buttons["History"].tap()
        // Each session row is a NavigationLink button whose label starts with
        // the split name followed by ", <weekday> <time>, ...". The first match
        // is the most recent seeded session.
        let sessionRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Upper Body,")).firstMatch
        XCTAssertTrue(sessionRow.waitForExistence(timeout: 15),
                      "Seeded 'Upper Body' session never appeared in History")
        sessionRow.tap()
        XCTAssertTrue(app.navigationBars["Workout Details"].waitForExistence(timeout: 10),
                      "Workout Details did not open")
    }

    private func enterHistoryEditMode(_ app: XCUIApplication) {
        let editButton = app.navigationBars["Workout Details"].buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit button missing")
        editButton.tap()
        XCTAssertTrue(app.navigationBars["Workout Details"].buttons["Done"].waitForExistence(timeout: 5),
                      "Edit did not toggle to Done")
    }

    private func startUpperBodyWorkout(_ app: XCUIApplication, startingExercise: String) {
        app.tabBars.buttons["Splits"].tap()
        let split = app.staticTexts["Upper Body"].firstMatch
        XCTAssertTrue(split.waitForExistence(timeout: 15), "Upper Body split missing")
        split.tap()
        let start = app.buttons["Start Workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Start Workout button missing")
        start.tap()
        // 4-exercise split -> starting-exercise picker.
        XCTAssertTrue(app.navigationBars["Starting Exercise"].waitForExistence(timeout: 10),
                      "Starting Exercise picker did not appear")
        button(app, containing: startingExercise).tap()
        XCTAssertTrue(app.navigationBars["Active Workout"].waitForExistence(timeout: 10),
                      "Active Workout did not open")
    }

    // MARK: - Element helpers

    private func staticTextCount(_ app: XCUIApplication, containing text: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).count
    }

    private func button(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func clearAndType(_ field: XCUIElement, _ newValue: String) {
        // Right-aligned Form text fields place the caret at the *start* on a
        // plain tap, so backspace is a no-op and typed text prepends. Tap the
        // trailing edge to land the caret at the end, then clear generously.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        field.typeText(newValue)
    }

    /// Taps a button inside a presented confirmationDialog (action sheet),
    /// disambiguating from an identically-labelled button still in the tree
    /// underneath (e.g. the editor's own "Delete Set").
    private func confirmDialogButton(_ app: XCUIApplication, _ label: String) {
        let sheetButton = app.sheets.buttons[label]
        if sheetButton.waitForExistence(timeout: 4) {
            sheetButton.tap()
            return
        }
        let matches = app.buttons.matching(identifier: label)
        XCTAssertGreaterThan(matches.count, 0, "Dialog button '\(label)' not found")
        matches.element(boundBy: matches.count - 1).tap()
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - A1: History edit-mode controls

    func testHistoryEditModeControls() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        XCTAssertTrue(app.buttons["Add Exercise"].waitForExistence(timeout: 5),
                      "Add Exercise control missing in edit mode")
        XCTAssertTrue(app.buttons["Add Set"].firstMatch.exists,
                      "Add Set control missing in edit mode")
        XCTAssertTrue(app.buttons["Edit Time"].exists,
                      "Edit Time (pencil) control missing in edit mode")
        snap(app, "A1-history-edit-mode")
    }

    // MARK: - A3: Edit a set's value

    func testEditSetValue() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        // First Chest Press set is "30.0 kg x 12".
        let setRow = button(app, containing: "30.0 kg x 12")
        XCTAssertTrue(setRow.waitForExistence(timeout: 5), "Chest Press set row not found")
        setRow.tap()

        XCTAssertTrue(app.navigationBars["Edit Set"].waitForExistence(timeout: 5),
                      "Edit Set sheet did not appear")
        XCTAssertTrue(app.staticTexts["Weight (kg)"].exists, "Weight field label missing")
        XCTAssertTrue(app.staticTexts["Reps"].exists, "Reps field label missing")

        let weightField = app.textFields["setEditorWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        clearAndType(weightField, "40")
        app.navigationBars["Edit Set"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["40.0 kg x 12"].waitForExistence(timeout: 5),
                      "Edited value 40.0 kg x 12 not visible in timeline")
        snap(app, "A3-edit-set-value")
    }

    // MARK: - A3: Delete a set

    func testDeleteSet() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        let before = staticTextCount(app, containing: "30.0 kg x 12")
        XCTAssertEqual(before, 4, "Expected 4 Chest Press sets before delete")

        button(app, containing: "30.0 kg x 12").tap()
        XCTAssertTrue(app.navigationBars["Edit Set"].waitForExistence(timeout: 5))

        app.buttons["Delete Set"].firstMatch.tap()
        // Confirmation dialog "Delete Set?" -> destructive "Delete Set".
        confirmDialogButton(app, "Delete Set")

        // Sheet dismisses; one fewer set.
        XCTAssertTrue(app.navigationBars["Workout Details"].waitForExistence(timeout: 5))
        var after = staticTextCount(app, containing: "30.0 kg x 12")
        // Allow the query to settle.
        var tries = 0
        while after != 3 && tries < 10 { usleep(300_000); after = staticTextCount(app, containing: "30.0 kg x 12"); tries += 1 }
        XCTAssertEqual(after, 3, "Expected 3 Chest Press sets after delete")
        snap(app, "A3-delete-set")
    }

    // MARK: - A4: Add a set

    func testAddSet() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        // First "Add Set" belongs to the first timeline card (Chest Press).
        app.buttons["Add Set"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Add Set"].waitForExistence(timeout: 5),
                      "Add Set editor did not appear")

        // Pre-filled from last set; make the new set uniquely identifiable.
        let weightField = app.textFields["setEditorWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        clearAndType(weightField, "99")
        app.navigationBars["Add Set"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["99.0 kg x 12"].waitForExistence(timeout: 5),
                      "Newly added set 99.0 kg x 12 not visible in timeline")
        snap(app, "A4-add-set")
    }

    // MARK: - A5: Add Exercise double-sheet (Commit 6754b84 timing fix)

    func testAddExerciseDoubleSheet() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        var results: [Bool] = []
        let iterations = 3
        for i in 0..<iterations {
            let addExercise = app.buttons["Add Exercise"]
            XCTAssertTrue(addExercise.waitForExistence(timeout: 5), "Add Exercise missing (iter \(i))")
            addExercise.tap()

            // Picker sheet.
            XCTAssertTrue(app.navigationBars["Add Exercise"].waitForExistence(timeout: 5),
                          "Exercise picker did not appear (iter \(i))")
            // Plank is the only unperformed split exercise -> pick it.
            let plank = app.buttons["Plank"].firstMatch
            XCTAssertTrue(plank.waitForExistence(timeout: 5), "Plank not pickable (iter \(i))")
            plank.tap()

            // CRITICAL: the add-set editor must reliably follow the picker dismissal.
            let editorAppeared = app.navigationBars["Add Set"].waitForExistence(timeout: 6)
            results.append(editorAppeared)
            XCTAssertTrue(editorAppeared,
                          "Add-Set editor did NOT appear after picking exercise (iter \(i)) — double-sheet regression")

            // Cancel so Plank stays unperformed and remains pickable next round.
            app.navigationBars["Add Set"].buttons["Cancel"].tap()
            XCTAssertTrue(app.navigationBars["Workout Details"].waitForExistence(timeout: 5))
        }
        snap(app, "A5-add-exercise-double-sheet")
        XCTAssertEqual(results, Array(repeating: true, count: iterations),
                       "Add-Set editor failed to appear on some iterations: \(results)")
    }

    // MARK: - A4: Remove Exercise (also verifies WorkoutPersistence bugfix E2E)

    func testRemoveExercise() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        // Bicep Curl performed 3 sets of "15.0 kg x 12".
        XCTAssertEqual(staticTextCount(app, containing: "15.0 kg x 12"), 3,
                       "Expected 3 Bicep Curl sets before removal")

        let menu = app.buttons["exerciseMenu_Bicep Curl"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Bicep Curl ellipsis menu not found")
        menu.tap()

        let removeItem = app.buttons["Remove Exercise"]
        XCTAssertTrue(removeItem.waitForExistence(timeout: 5), "Remove Exercise menu item missing")
        removeItem.tap()

        // Confirmation dialog "Remove Exercise?" -> destructive "Remove Exercise".
        let confirm = app.buttons["Remove Exercise"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.navigationBars["Workout Details"].waitForExistence(timeout: 5))

        var curlSets = staticTextCount(app, containing: "15.0 kg x 12")
        var tries = 0
        while curlSets != 0 && tries < 10 { usleep(300_000); curlSets = staticTextCount(app, containing: "15.0 kg x 12"); tries += 1 }
        XCTAssertEqual(curlSets, 0, "Bicep Curl sets still present after removal")

        // Post-removal, "Bicep Curl" text only survives in the Skipped section.
        XCTAssertTrue(app.staticTexts["Skipped"].exists, "Skipped section missing")
        XCTAssertTrue(app.staticTexts["Bicep Curl"].waitForExistence(timeout: 5),
                      "Bicep Curl did not move into the Skipped section")
        snap(app, "A4-remove-exercise")
    }

    // MARK: - A2: Session time editor

    func testSessionTimeEditor() {
        let app = launchSeeded()
        openFirstHistoryDetail(app)
        enterHistoryEditMode(app)

        app.buttons["Edit Time"].tap()
        XCTAssertTrue(app.navigationBars["Edit Time"].waitForExistence(timeout: 5),
                      "Edit Time sheet did not appear")
        XCTAssertTrue(app.staticTexts["Start"].exists, "Start date picker missing")
        XCTAssertTrue(app.staticTexts["End"].exists, "End date picker missing")

        // Cancel path.
        app.navigationBars["Edit Time"].buttons["Cancel"].tap()
        XCTAssertFalse(app.navigationBars["Edit Time"].waitForExistence(timeout: 2),
                       "Edit Time sheet did not dismiss on Cancel")

        // Save path (no change).
        app.buttons["Edit Time"].tap()
        XCTAssertTrue(app.navigationBars["Edit Time"].waitForExistence(timeout: 5))
        snap(app, "A2-session-time-editor")
        app.navigationBars["Edit Time"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Workout Details"].waitForExistence(timeout: 5),
                      "Did not return to detail after Save")
    }

    // MARK: - B: In-workout set editing

    func testInWorkoutEditing() {
        let app = launchSeeded()
        startUpperBodyWorkout(app, startingExercise: "Chest Press")

        // Log a set (inputs are pre-filled with 30.0 x 12).
        let logSet = app.buttons["Log Set"].firstMatch
        XCTAssertTrue(logSet.waitForExistence(timeout: 5), "Log Set button missing")
        logSet.tap()

        // Logging pushes the rest timer; return to the session.
        let continueBtn = app.buttons["Continue Workout"]
        XCTAssertTrue(continueBtn.waitForExistence(timeout: 8), "Rest timer did not appear")
        continueBtn.tap()

        // "This Exercise" now lists the logged set.
        XCTAssertTrue(app.staticTexts["This Exercise"].waitForExistence(timeout: 5),
                      "This Exercise section missing")
        let setRow = button(app, containing: "30.0 kg x 12")
        XCTAssertTrue(setRow.waitForExistence(timeout: 5), "Logged set not shown in This Exercise")

        // Edit via tap.
        setRow.tap()
        XCTAssertTrue(app.navigationBars["Edit Set"].waitForExistence(timeout: 5),
                      "Set editor did not open from This Exercise")
        let weightField = app.textFields["setEditorWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        clearAndType(weightField, "42")
        app.navigationBars["Edit Set"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["42.0 kg x 12"].waitForExistence(timeout: 5),
                      "Edited in-workout set not reflected")
        snap(app, "B-in-workout-edit")

        // Long-press context menu shows Edit Set / Delete Set.
        let editedRow = button(app, containing: "42.0 kg x 12")
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5))
        editedRow.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Edit Set"].waitForExistence(timeout: 5),
                      "Context menu Edit Set missing")
        XCTAssertTrue(app.buttons["Delete Set"].exists,
                      "Context menu Delete Set missing")
        snap(app, "B-context-menu")

        // Delete through the context menu.
        app.buttons["Delete Set"].firstMatch.tap()
        confirmDialogButton(app, "Delete Set")
        XCTAssertFalse(app.staticTexts["42.0 kg x 12"].waitForExistence(timeout: 3),
                       "Set still present after in-workout delete")
    }

    // MARK: - C: Progression banner

    func testProgressionBanner() {
        let app = launchSeeded()
        startUpperBodyWorkout(app, startingExercise: "Chest Press")

        XCTAssertTrue(app.staticTexts["Time to level up"].waitForExistence(timeout: 8),
                      "Progression 'Time to level up' banner not shown for Chest Press")
        snap(app, "C-progression-banner")

        // Chart toolbar button opens the exercise stats view.
        let statsButton = app.buttons["exerciseStatsButton"]
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5), "Stats toolbar button missing")
        statsButton.tap()
        XCTAssertTrue(app.navigationBars["Chest Press"].waitForExistence(timeout: 8),
                      "Exercise stats detail did not open")
        snap(app, "C-stats-view")
    }
}
