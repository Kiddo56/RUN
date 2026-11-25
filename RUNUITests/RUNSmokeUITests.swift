import XCTest

@MainActor
final class RUNSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchMapSettingsAndDiagnosticsSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        let mapTab = app.tabBars.buttons["Map"].firstMatch
        XCTAssertTrue(mapTab.waitForExistence(timeout: 15), "Map tab button should appear")
        captureScreenshot(named: "01_map_home", app: app)

        let settingsTab = app.tabBars.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab button should appear")
        settingsTab.tap()

        let versionRow = app.descendants(matching: .any)["settings.version"]
        XCTAssertTrue(versionRow.waitForExistence(timeout: 5), "Settings version row should appear")
        let shaRow = app.descendants(matching: .any)["settings.commitSHA"]
        XCTAssertTrue(shaRow.waitForExistence(timeout: 5), "Settings commit SHA row should appear")
        captureScreenshot(named: "02_settings", app: app)

        let diagnosticsLink = app.descendants(matching: .any)["settings.diagnosticsLink"]
        XCTAssertTrue(diagnosticsLink.waitForExistence(timeout: 5), "Diagnostics link should appear")
        diagnosticsLink.tap()

        let addEventButton = app.buttons["diagnostics.addEventButton"]
        XCTAssertTrue(addEventButton.waitForExistence(timeout: 5), "Diagnostics view should load")
        addEventButton.tap()
        captureScreenshot(named: "03_diagnostics", app: app)
    }

    private func captureScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
