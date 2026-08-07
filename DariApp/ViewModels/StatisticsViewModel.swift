//
//  StatisticsViewModel.swift
//  DariApp
//
//  Berechnet Kennzahlen aus Karten und Wiederholungs-Historie.
//  Reine Aggregationslogik, getrennt von der View und damit testbar.
//

import Foundation

struct StatisticsSnapshot: Sendable {
    var totalCards = 0
    var activeCards = 0
    var inactiveCards = 0
    var reviewsToday = 0
    var successRate: Double = 0        // 0...1
    var streak = 0                     // aufeinanderfolgende Lern-Tage
    var averageAnswerTime: TimeInterval = 0
    var hardestCards: [Card] = []      // hoechste Schwierigkeit
    var topTags: [(name: String, count: Int)] = []
    var reviewsPerDay: [(date: Date, count: Int)] = []  // letzte 14 Tage
}

enum StatisticsCalculator {

    static func snapshot(cards: [Card], logs: [ReviewLog], calendar: Calendar = .current, now: Date = .now) -> StatisticsSnapshot {
        var snap = StatisticsSnapshot()

        snap.totalCards = cards.count
        snap.activeCards = cards.filter(\.isActive).count
        snap.inactiveCards = snap.totalCards - snap.activeCards

        let startOfToday = calendar.startOfDay(for: now)
        snap.reviewsToday = logs.filter { $0.date >= startOfToday }.count

        if !logs.isEmpty {
            let correct = logs.filter { $0.rating != .again }.count
            snap.successRate = Double(correct) / Double(logs.count)
            let totalTime = logs.reduce(0) { $0 + $1.answerTime }
            snap.averageAnswerTime = totalTime / Double(logs.count)
        }

        snap.streak = computeStreak(logs: logs, calendar: calendar, now: now)

        snap.hardestCards = cards
            .filter { $0.reps > 0 }
            .sorted { $0.difficulty > $1.difficulty }
            .prefix(5)
            .map { $0 }

        snap.topTags = computeTopTags(cards: cards)
        snap.reviewsPerDay = computeReviewsPerDay(logs: logs, calendar: calendar, now: now, days: 14)

        return snap
    }

    // MARK: - Bausteine

    private static func computeStreak(logs: [ReviewLog], calendar: Calendar, now: Date) -> Int {
        let days = Set(logs.map { calendar.startOfDay(for: $0.date) })
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
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (name: $0.key, count: $0.value) }
    }

    private static func computeReviewsPerDay(logs: [ReviewLog], calendar: Calendar, now: Date, days: Int) -> [(date: Date, count: Int)] {
        var result: [(date: Date, count: Int)] = []
        let today = calendar.startOfDay(for: now)
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let count = logs.filter { $0.date >= day && $0.date < next }.count
            result.append((date: day, count: count))
        }
        return result
    }
}
