//
//  StatisticsTests.swift
//  DariAppTests
//
//  Prueft die Aggregationslogik der Statistik (Zaehlungen, Erfolgsquote,
//  Streak, Tagesziel, XP). Nutzt In-Memory-SwiftData, um echte Modelle zu erzeugen.
//

import Testing
import Foundation
import SwiftData
@testable import DariApp

@MainActor
struct StatisticsTests {

    @Test("Zaehlt aktive und inaktive Karten korrekt")
    func cardCounts() {
        let env = TestEnv()
        let active = env.addCard(["a"], ["ب"])
        let inactive = env.addCard(["b"], ["پ"])
        inactive.isActive = false

        let snap = StatisticsCalculator.snapshot(cards: [active, inactive], logs: [])
        #expect(snap.totalCards == 2)
        #expect(snap.activeCards == 1)
        #expect(snap.inactiveCards == 1)
        withExtendedLifetime(env) {}
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

    @Test("Streak: eine Luecke beendet die Serie, gestern zaehlt noch")
    func streakGap() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let card = Card(germanTranslations: ["a"], persianTranslations: ["ب"])
        func log(_ daysAgo: Int) -> ReviewLog {
            ReviewLog(card: card, rating: .good, answerTime: 1, mode: .flip, date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }
        #expect(StatisticsCalculator.snapshot(cards: [card], logs: [log(1), log(2)], calendar: calendar, now: now).streak == 2)
        #expect(StatisticsCalculator.snapshot(cards: [card], logs: [log(0), log(2)], calendar: calendar, now: now).streak == 1)
        #expect(StatisticsCalculator.snapshot(cards: [card], logs: [log(2)], calendar: calendar, now: now).streak == 0)
    }

    @Test("Tagesziel zaehlt keine Uebungswiederholungen; XP und Level werden aus dem Verlauf berechnet")
    func goalAndXP() {
        let card = Card(germanTranslations: ["a"], persianTranslations: ["ب"])
        let logs = [
            ReviewLog(card: card, rating: .good, answerTime: 1, mode: .flip),                       // 10
            ReviewLog(card: card, rating: .again, answerTime: 1, mode: .flip, isPractice: true),    // 1
            ReviewLog(card: card, rating: .easy, answerTime: 1, mode: .flip, wasWeak: true)         // 12 + 5
        ]
        let snap = StatisticsCalculator.snapshot(cards: [card], logs: logs, dailyGoal: 2)
        #expect(snap.reviewsToday == 2)
        #expect(snap.goalReached)
        #expect(snap.xp == 10 + 1 + 17)
        #expect(snap.level.level == 1)
        #expect(snap.weakRight == 1)
    }

    @Test("Wissensstand: neu / lernend / gefestigt")
    func knowledge() {
        let fresh = Card(germanTranslations: ["a"], persianTranslations: ["ب"])
        let learning = Card(germanTranslations: ["b"], persianTranslations: ["پ"])
        learning.reps = 2; learning.stability = 3
        let solid = Card(germanTranslations: ["c"], persianTranslations: ["ت"])
        solid.reps = 5; solid.stability = 30
        let snap = StatisticsCalculator.snapshot(cards: [fresh, learning, solid], logs: [])
        #expect(snap.knownNew == 1)
        #expect(snap.knownLearning == 1)
        #expect(snap.knownSolid == 1)
        #expect(snap.practisedCards == 2)
    }
}
