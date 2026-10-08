//
//  DariAppUITests.swift
//  DariAppUITests
//
//  Oberflaechen-Tests der Kernfluesse (Navigation, Karten, Lernen, Uebungen,
//  Backup). Die App startet mit einer fluechtigen Datenbank (-zaraInMemory), damit
//  jeder Test sauber beginnt. Bildschirmfotos werden – falls SCREENSHOT_DIR gesetzt
//  ist – als PNG abgelegt (Cloud-Build).
//

import XCTest

final class DariAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Hilfen

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-zaraInMemory"]
        app.launch()
        return app
    }

    @MainActor
    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    /// Findet ein Element über seine Kennung, egal ob Button, Link oder Container.
    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Schreibt die Bedienelemente-Hierarchie als Text (nur im Cloud-Build, zur Fehlersuche).
    @MainActor
    private func dump(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        try? app.debugDescription.write(toFile: dir + "/" + name + ".txt", atomically: true, encoding: .utf8)
    }

    /// Scrollt, bis ein Element in der (faul geladenen) Liste vorhanden ist.
    @MainActor
    private func reveal(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let el = element(app, identifier)
        var tries = 0
        while !el.exists && tries < 6 { app.swipeUp(); tries += 1 }
        return el
    }

    @MainActor
    private func loadSampleCards(_ app: XCUIApplication) {
        app.tabBars.buttons["Karten"].tap()
        let sample = app.buttons["Beispielkarten laden"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        sample.tap()
        let row = element(app, "card.row")
        let found = row.waitForExistence(timeout: 8)
        if !found { shot("fehler-karten"); dump(app, "fehler-karten") }
        XCTAssertTrue(found, "Beispielkarten wurden nicht angezeigt")
    }

    // MARK: Tests

    @MainActor
    func testTabBarShowsAllTabs() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Heute"].waitForExistence(timeout: 8))
        for name in ["Üben", "Karten", "Statistik", "Mehr"] {
            XCTAssertTrue(app.tabBars.buttons[name].exists, "Tab \(name) fehlt")
        }
        shot("01-heute-leer")
    }

    @MainActor
    func testEmptyStateOffersFirstCard() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["today.hero"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["today.hero"].label.contains("Erste Karte anlegen"))
    }

    @MainActor
    func testSampleCardsAndLearnToday() throws {
        let app = launch()
        loadSampleCards(app)
        shot("02-karten")
        app.tabBars.buttons["Heute"].tap()
        let hero = app.buttons["today.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Heute lernen"), "Hero: \(hero.label)")
        shot("03-heute-mit-karten")
        hero.tap()
        XCTAssertTrue(app.navigationBars["Lernen"].waitForExistence(timeout: 8))
        shot("04-lernen-sitzung")
    }

    @MainActor
    func testOpenCardEditor() throws {
        let app = launch()
        app.tabBars.buttons["Karten"].tap()
        app.buttons["Karte anlegen"].tap()
        XCTAssertTrue(app.navigationBars["Neue Karte"].waitForExistence(timeout: 5))
        shot("05-karten-editor")
    }

    @MainActor
    func testPracticeHubAndMix() throws {
        let app = launch()
        loadSampleCards(app)
        app.tabBars.buttons["Üben"].tap()
        XCTAssertTrue(app.navigationBars["Üben"].waitForExistence(timeout: 5))
        shot("06-ueben")
        let mix = element(app, "hub.mix")
        XCTAssertTrue(mix.waitForExistence(timeout: 5))
        mix.tap()
        XCTAssertTrue(app.navigationBars["5-Minuten-Spiel"].waitForExistence(timeout: 8))
        shot("07-mix")
    }

    @MainActor
    func testGrammarFlow() throws {
        let app = launch()
        app.tabBars.buttons["Üben"].tap()
        let grammar = reveal(app, "hub.grammar")
        if !grammar.waitForExistence(timeout: 8) { shot("fehler-hub"); dump(app, "fehler-hub") }
        XCTAssertTrue(grammar.exists)
        grammar.tap()
        let start = element(app, "grammar.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        shot("08-grammatik-auswahl")
        start.tap()
        XCTAssertTrue(app.navigationBars["Grammatik"].waitForExistence(timeout: 8))
        shot("09-grammatik-frage")
    }

    @MainActor
    func testGrammarAnswerAndContinue() throws {
        let app = launch()
        app.tabBars.buttons["Üben"].tap()
        let grammar = reveal(app, "hub.grammar")
        XCTAssertTrue(grammar.waitForExistence(timeout: 8))
        grammar.tap()
        let start = element(app, "grammar.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let first = element(app, "option.0")
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        first.tap()
        let next = element(app, "practice.next")
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Nach der Antwort muss „Weiter“ erscheinen")
        shot("09b-grammatik-antwort")
        next.tap()
        XCTAssertTrue(element(app, "option.0").waitForExistence(timeout: 5), "Nächste Frage erwartet")
    }

    @MainActor
    func testClozeAnswerAndContinue() throws {
        let app = launch()
        app.tabBars.buttons["Üben"].tap()
        let cloze = element(app, "hub.cloze")
        XCTAssertTrue(cloze.waitForExistence(timeout: 5))
        cloze.tap()
        let first = element(app, "option.0")
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        first.tap()
        let next = element(app, "practice.next")
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        shot("10b-lueckentext-antwort")
        next.tap()
        XCTAssertTrue(element(app, "option.0").waitForExistence(timeout: 5))
    }

    @MainActor
    func testFlipSessionCompletes() throws {
        let app = launch()
        loadSampleCards(app)
        app.tabBars.buttons["Heute"].tap()
        let hero = app.buttons["today.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()
        var rounds = 0
        while rounds < 20 && !app.staticTexts["Session abgeschlossen"].exists {
            let flipHint = app.staticTexts["Zum Umdrehen tippen"]
            XCTAssertTrue(flipHint.waitForExistence(timeout: 8) || app.staticTexts["Session abgeschlossen"].exists, "Karte erwartet (Runde \(rounds))")
            if app.staticTexts["Session abgeschlossen"].exists { break }
            element(app, "flip.card").tap()
            let good = app.buttons["Gut"]
            XCTAssertTrue(good.waitForExistence(timeout: 5))
            good.tap()
            rounds += 1
        }
        XCTAssertTrue(app.staticTexts["Session abgeschlossen"].waitForExistence(timeout: 8), "Die Lerneinheit muss abgeschlossen werden")
        shot("04b-lernen-fertig")
        XCTAssertGreaterThanOrEqual(rounds, 8)
    }

    @MainActor
    func testClozeSession() throws {
        let app = launch()
        app.tabBars.buttons["Üben"].tap()
        let cloze = element(app, "hub.cloze")
        XCTAssertTrue(cloze.waitForExistence(timeout: 5))
        cloze.tap()
        XCTAssertTrue(app.navigationBars["Lückentext"].waitForExistence(timeout: 8))
        shot("10-lueckentext")
    }

    @MainActor
    func testSettingsAndBackupScreen() throws {
        let app = launch()
        app.tabBars.buttons["Mehr"].tap()
        XCTAssertTrue(app.navigationBars["Mehr"].waitForExistence(timeout: 5))
        shot("11-mehr")
        let backup = app.buttons["settings.backup"]
        XCTAssertTrue(backup.waitForExistence(timeout: 5))
        backup.tap()
        XCTAssertTrue(app.buttons["backup.export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["backup.import"].exists)
        shot("12-backup")
    }

    @MainActor
    func testStatistics() throws {
        let app = launch()
        loadSampleCards(app)
        app.tabBars.buttons["Statistik"].tap()
        XCTAssertTrue(app.navigationBars["Statistik"].waitForExistence(timeout: 5))
        shot("13-statistik")
    }
}
