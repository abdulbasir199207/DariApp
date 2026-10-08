//
//  StatisticsViewModel.swift
//  DariApp
//
//  Berechnet Kennzahlen aus Karten und Wiederholungs-Historie.
//  Reine Aggregationslogik, getrennt von der View und damit testbar.
//  Die Historie wird in einem einzigen Durchlauf ausgewertet (schnell auch bei
//  vielen tausend Eintraegen).
//

import Foundation

// Hinweis: Kein 'Sendable', weil der Snapshot 'Card'-Objekte (SwiftData @Model,
// nicht sendbar) enthaelt. Er wird ausschliesslich synchron auf dem MainActor
// (in den Views) erzeugt und verwendet, also ist Sendable hier nicht noetig.
struct StatisticsSnapshot {
    var totalCards = 0
    var activeCards = 0
    var inactiveCards = 0
    /// Antworten heute ohne Uebungswiederholungen (Grundlage des Tagesziels).
    var reviewsToday = 0
    var successRate: Double = 0        // 0...1
    var streak = 0                     // aufeinanderfolgende Lern-Tage
    var averageAnswerTime: TimeInterval = 0
    var hardestCards: [Card] = []      // schwierigste Woerter (Schwaeche-Bewertung)
    var topTags: [(name: String, count: Int)] = []
    var reviewsPerDay: [(date: Date, count: Int)] = []  // letzte 14 Tage

    // Fortschritt & Spielelemente
    var totalReviews = 0
    var xp = 0
    var level = Gamification.level(forXP: 0)
    var dailyGoal = 20
    var goalReached: Bool { reviewsToday >= dailyGoal }
    var goalFraction: Double { dailyGoal > 0 ? min(Double(reviewsToday) / Double(dailyGoal), 1) : 0 }
    var dueCount = 0
    var weakCount = 0
    var practisedCards = 0
    var weakRight = 0
    var knownNew = 0
    var knownLearning = 0
    var knownSolid = 0
}

enum StatisticsCalculator {

    static func snapshot(
        cards: [Card],
        logs: [ReviewLog],
        dailyGoal: Int = 20,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> StatisticsSnapshot {
        var snap = StatisticsSnapshot()
        snap.dailyGoal = dailyGoal

        snap.totalCards = cards.count
        snap.activeCards = cards.filter(\.isActive).count
        snap.inactiveCards = snap.totalCards - snap.activeCards

        // Einzeldurchlauf ueber die Historie.
        let startOfToday = calendar.startOfDay(for: now)
        var correct = 0
        var totalTime: TimeInterval = 0
        var xp = 0
        var weakRight = 0
        var days = Set<Date>()
        var perDay: [Date: Int] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.date)
            days.insert(day)
            perDay[day, default: 0] += 1
            if log.rating != .again { correct += 1 }
            totalTime += log.answerTime
            xp += Gamification.xp(for: log)
            if log.wasWeak && log.rating.rawValue >= FSRSRating.good.rawValue { weakRight += 1 }
            if log.date >= startOfToday && !log.isPractice { snap.reviewsToday += 1 }
        }
        snap.totalReviews = logs.count
        if !logs.isEmpty {
            snap.successRate = Double(correct) / Double(logs.count)
            snap.averageAnswerTime = totalTime / Double(logs.count)
        }
        snap.xp = xp
        snap.level = Gamification.level(forXP: xp)
        snap.weakRight = weakRight
        snap.streak = computeStreak(days: days, calendar: calendar, now: now)

        // Schwierige Woerter
        let weak = Adaptive.weakCards(cards, now: now)
        snap.weakCount = weak.count
        snap.hardestCards = Array(weak.prefix(5))
        snap.dueCount = cards.filter { $0.isDue(asOf: now) }.count

        // Wissensstand
        for card in cards where card.isActive {
            if card.reps == 0 { snap.knownNew += 1 }
            else if card.stability >= 21 { snap.knownSolid += 1 }
            else { snap.knownLearning += 1 }
        }
        snap.practisedCards = cards.filter { $0.reps > 0 }.count

        snap.topTags = computeTopTags(cards: cards)
        snap.reviewsPerDay = computeReviewsPerDay(perDay: perDay, calendar: calendar, now: now, days: 14)
        return snap
    }

    // MARK: - Bausteine

    private static func computeStreak(days: Set<Date>, calendar: Calendar, now: Date) -> Int {
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: now)
        // Startet der Streak heute oder gestern?
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private static func computeTopTags(cards: [Card]) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for card in cards {
            for tag in card.tags {
                counts[tag.name, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }
    }

    private static func computeReviewsPerDay(
        perDay: [Date: Int],
        calendar: Calendar,
        now: Date,
        days: Int
    ) -> [(date: Date, count: Int)] {
        var result: [(date: Date, count: Int)] = []
        let today = calendar.startOfDay(for: now)
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append((date: day, count: perDay[day, default: 0]))
        }
        return result
    }
}

/// Merkt sich den berechneten Snapshot, solange sich die Eingaben nicht aendern
/// (vermeidet mehrfaches Neuberechnen pro Bildschirm-Aufbau).
@MainActor
final class SnapshotCache {
    private var key = Int.min
    private var cached: StatisticsSnapshot?

    func snapshot(cards: [Card], logs: [ReviewLog], dailyGoal: Int) -> StatisticsSnapshot {
        let active = cards.reduce(0) { $0 + ($1.isActive ? 1 : 0) }
        let reps = cards.reduce(0) { $0 &+ $1.reps &+ $1.miss }
        var hasher = Hasher()
        hasher.combine(cards.count); hasher.combine(logs.count); hasher.combine(dailyGoal)
        hasher.combine(active); hasher.combine(reps)
        hasher.combine(Calendar.current.startOfDay(for: .now))
        let newKey = hasher.finalize()
        if let cached, newKey == key { return cached }
        let fresh = StatisticsCalculator.snapshot(cards: cards, logs: logs, dailyGoal: dailyGoal)
        key = newKey; cached = fresh
        return fresh
    }
}
