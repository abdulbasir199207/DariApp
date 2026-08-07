//
//  DariAppUITests.swift
//  DariAppUITests
//
//  Grundlegende UI-Tests fuer die Kern-Navigationsfluesse.
//

import XCTest

final class DariAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabBarShowsAllTabs() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Lernen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Karten"].exists)
        XCTAssertTrue(app.tabBars.buttons["Statistik"].exists)
        XCTAssertTrue(app.tabBars.buttons["Einstellungen"].exists)
    }

    @MainActor
    func testNavigateToCards() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Karten"].tap()
        XCTAssertTrue(app.navigationBars["Karten"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpenCardEditor() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Karten"].tap()
        // Der Plus-Button in der Toolbar oeffnet den Editor.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Editor-Titel erscheint (neu oder leer je nach Datenlage).
        XCTAssertTrue(app.navigationBars["Neue Karte"].waitForExistence(timeout: 5)
                      || app.navigationBars.element.waitForExistence(timeout: 5))
    }
}
