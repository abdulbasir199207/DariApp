//
//  StatisticsTests.swift
//  DariAppTests
//
//  Prueft die Aggregationslogik der Statistik (Zaehlungen, Erfolgsquote,
//  Streak). Nutzt In-Memory-SwiftData, um echte Modelle zu erzeugen.
//

import Testing
import Foundation
import SwiftData
@testable import DariApp

@MainActor
struct StatisticsTests {

    private func makeContext() -> ModelContext {
        ModelContainerFactory.makeInMemory().mainContext
    }

    @Test("Zaehlt aktive und inaktive Karten korrekt")
    func cardCounts() {
        let context = makeContext()
        let active = Card(germanTranslations: ["a"], persianTranslations: ["ب"])
        let inactive = Card(germanTranslations: ["b"], persianTranslations: ["پ"])
        inactive.isActive = false
        context.insert(active)
        context.insert(inactive)

        let snap = StatisticsCalculator.snapshot(cards: [active, inactive], logs: [])
        #expect(snap.totalCards == 2)
        #expect(snap.activeCards == 1)
        #expect(snap.inactiveCards == 1)
    }

    @Test("Erfolgsquote basiert auf Nicht-'again'-Antworten")
    func successRate() {
        let card = Card(germanTranslations: ["a"], persianTranslations: ["ب"])
        let logs = [
            ReviewLog(card: card, rating: .good, answerTime: 2, mode: .flip),
            ReviewLog(card: card, rating: .again, answerTime: 3, mode: .flip),
            ReviewLog(card: card, rating: .easy, answerTime: 1, mode: .flip),
            ReviewLog(card: card, rating: .good, answerTime: 2, mode: .flip)
        ]
        let snap = StatisticsCalculator.snapshot(cards: [card], logs: logs)
        #expect(abs(snap.successRate - 0.75) < 0.0001)
    }

    @Test("Streak zaehlt aufeinanderfolgende Tage")
    func streak() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let card = Card(germanTranslations: ["a"], persianTranslations: ["ب"])

        func log(daysAgo: Int) -> ReviewLog {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let l = ReviewLog(card: card, rating: .good, answerTime: 1, mode: .flip)
            l.date = date
            return l
        }
        let logs = [log(daysAgo: 0), log(daysAgo: 1), log(daysAgo: 2)]
        let snap = StatisticsCalculator.snapshot(cards: [card], logs: logs, calendar: calendar, now: now)
        #expect(snap.streak == 3)
    }
}
