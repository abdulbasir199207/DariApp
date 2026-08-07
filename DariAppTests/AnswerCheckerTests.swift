//
//  AnswerCheckerTests.swift
//  DariAppTests
//
//  Prueft die Antwortbewertung: Gross-/Kleinschreibung, Leerzeichen,
//  Tippfehler-Erkennung und persische Zeichennormalisierung.
//

import Testing
@testable import DariApp

struct AnswerCheckerTests {

    @Test("Exakte Uebereinstimmung ist perfekt")
    func exactMatch() {
        let q = AnswerChecker.evaluate(input: "Haus", against: ["Haus"], isPersian: false)
        #expect(q == .perfect)
    }

    @Test("Gross-/Kleinschreibung und Leerzeichen werden ignoriert")
    func caseAndWhitespaceIgnored() {
        let q = AnswerChecker.evaluate(input: "  hAuS ", against: ["Haus"], isPersian: false)
        #expect(q == .perfect)
    }

    @Test("Mehrere gueltige Loesungen werden akzeptiert")
    func multipleSolutions() {
        let q = AnswerChecker.evaluate(input: "Gebäude", against: ["Haus", "Gebäude"], isPersian: false)
        #expect(q == .perfect)
    }

    @Test("Ein einzelner Tippfehler wird als typo erkannt")
    func singleTypo() {
        let q = AnswerChecker.evaluate(input: "Haos", against: ["Haus"], isPersian: false)
        #expect(q == .typo)
    }

    @Test("Voellig falsche Antwort ist wrong")
    func completelyWrong() {
        let q = AnswerChecker.evaluate(input: "Auto", against: ["Haus"], isPersian: false)
        #expect(q == .wrong)
    }

    @Test("Kurze Woerter tolerieren keinen Tippfehler")
    func shortWordsStrict() {
        let q = AnswerChecker.evaluate(input: "Tag", against: ["Tor"], isPersian: false)
        #expect(q == .wrong)
    }

    @Test("Persische Zeichenvarianten werden normalisiert")
    func persianNormalization() {
        // Arabisches Ya/Kaf vs. persisches Ya/Kaf.
        let q = AnswerChecker.evaluate(input: "كتاب", against: ["کتاب"], isPersian: true)
        #expect(q == .perfect)
    }

    @Test("Leere Eingabe ist wrong")
    func emptyInput() {
        let q = AnswerChecker.evaluate(input: "   ", against: ["Haus"], isPersian: false)
        #expect(q == .wrong)
    }

    @Test("Levenshtein-Distanz ist korrekt")
    func levenshtein() {
        #expect(AnswerChecker.levenshtein("kitten", "sitting") == 3)
        #expect(AnswerChecker.levenshtein("haus", "haus") == 0)
    }
}
