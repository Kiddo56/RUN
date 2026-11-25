import XCTest

@MainActor
final class RUNSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchRecordHistorySettingsAndDiagnosticsSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        let startButton = app.buttons["record.startButton"].firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 15), "Record start button should appear")
        captureScreenshot(named: "01_record", app: app)

        let historyTab = app.buttons["History"].firstMatch
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5), "History tab button should appear")
        historyTab.tap()
        captureScreenshot(named: "02_history", app: app)

        let settingsTab = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab button should appear")
        settingsTab.tap()

        let versionRow = app.descendants(matching: .any)["settings.version"]
        XCTAssertTrue(versionRow.waitForExistence(timeout: 5), "Settings version row should appear")
        let shaRow = app.descendants(matching: .any)["settings.commitSHA"]
        XCTAssertTrue(shaRow.waitForExistence(timeout: 5), "Settings commit SHA row should appear")
        captureScreenshot(named: "03_settings", app: app)

        let diagnosticsLink = app.descendants(matching: .any)["settings.diagnosticsLink"]
        XCTAssertTrue(diagnosticsLink.waitForExistence(timeout: 5), "Diagnostics link should appear")
        diagnosticsLink.tap()

        let addEventButton = app.buttons["diagnostics.addEventButton"]
        XCTAssertTrue(addEventButton.waitForExistence(timeout: 5), "Diagnostics view should load")
        addEventButton.tap()
        captureScreenshot(named: "04_diagnostics", app: app)
    }

    private func captureScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
