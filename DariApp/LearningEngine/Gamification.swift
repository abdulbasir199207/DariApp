//
//  Gamification.swift
//  DariApp
//
//  Spielelemente mit paedagogischem Nutzen: Punkte (XP) gibt es fuers richtige
//  Erinnern, mehr fuer schwierige Woerter; Levels zeigen den Gesamtfortschritt,
//  Meilensteine belohnen Regelmaessigkeit. XP werden immer aus dem Verlauf
//  berechnet – es gibt keinen separaten Zaehler, der verloren gehen koennte.
//

import Foundation

struct LevelInfo: Sendable, Equatable {
    var level: Int
    var xp: Int
    var base: Int
    var next: Int

    var fraction: Double {
        guard next > base else { return 0 }
        return min(max(Double(xp - base) / Double(next - base), 0), 1)
    }
}

struct Achievement: Identifiable, Sendable {
    let id: String
    let icon: String        // SF Symbol
    let name: String
    let detail: String
    let isUnlocked: @Sendable (StatisticsSnapshot) -> Bool
}

enum Gamification {

    /// Erfahrungspunkte je Antwort.
    static func xp(rating: FSRSRating, wasWeak: Bool, isPractice: Bool) -> Int {
        var xp: Int
        switch rating {
        case .easy: xp = 12
        case .good: xp = 10
        case .hard: xp = 6
        case .again: xp = 2
        }
        if wasWeak && rating.rawValue >= FSRSRating.good.rawValue { xp += 5 }
        if isPractice { xp = Int((Double(xp) / 2).rounded()) }
        return xp
    }

    static func xp(for log: ReviewLog) -> Int {
        xp(rating: log.rating, wasWeak: log.wasWeak, isPractice: log.isPractice)
    }

    /// Level n beginnt bei 50·(n−1)² XP.
    static func level(forXP xp: Int) -> LevelInfo {
        let clamped = max(xp, 0)
        let level = Int((Double(clamped) / 50).squareRoot()) + 1
        return LevelInfo(level: level, xp: clamped, base: 50 * (level - 1) * (level - 1), next: 50 * level * level)
    }

    static let achievements: [Achievement] = [
        Achievement(id: "start", icon: "star.fill", name: "Erster Schritt", detail: "Die erste Antwort gegeben.") { $0.totalReviews >= 1 },
        Achievement(id: "streak3", icon: "flame.fill", name: "3 Tage in Folge", detail: "Drei Tage hintereinander gelernt.") { $0.streak >= 3 },
        Achievement(id: "streak7", icon: "flame.fill", name: "Eine Woche", detail: "7 Tage Lernserie.") { $0.streak >= 7 },
        Achievement(id: "streak30", icon: "trophy.fill", name: "Ein Monat", detail: "30 Tage Lernserie.") { $0.streak >= 30 },
        Achievement(id: "goal", icon: "target", name: "Tagesziel", detail: "Das Tagesziel heute erreicht.") { $0.goalReached },
        Achievement(id: "words50", icon: "rectangle.stack.fill", name: "50 Wörter", detail: "50 Wörter schon geübt.") { $0.practisedCards >= 50 },
        Achievement(id: "words200", icon: "rectangle.stack.fill", name: "200 Wörter", detail: "200 Wörter schon geübt.") { $0.practisedCards >= 200 },
        Achievement(id: "weak10", icon: "checkmark.seal.fill", name: "Schwächen besiegt", detail: "10× ein schwieriges Wort richtig beantwortet.") { $0.weakRight >= 10 },
        Achievement(id: "solid20", icon: "diamond.fill", name: "Gefestigt", detail: "20 Wörter fest im Gedächtnis.") { $0.knownSolid >= 20 }
    ]
}
