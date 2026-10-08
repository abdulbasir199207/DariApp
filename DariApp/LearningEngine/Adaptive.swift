//
//  Adaptive.swift
//  DariApp
//
//  Adaptives Lernen: Je oefter ein Wort falsch war (oder je schwieriger FSRS
//  es einstuft), desto frueher und haeufiger kommt es wieder. Gleiche Formel
//  wie in der Web-Version (weakScore).
//

import Foundation

enum Adaptive {

    /// Ab diesem Wert gilt ein Wort als „schwierig".
    static let weakThreshold = 1.2

    /// 0 = sicher beherrscht ... > 1,2 = schwierig. Kombiniert Fehlerquote,
    /// FSRS-Schwierigkeit, Rueckfaelle, Spiel-Fehler und Vergessenswahrscheinlichkeit.
    static func weakScore(_ card: Card, now: Date = .now, fsrs: FSRS = FSRS()) -> Double {
        let reps = card.reps
        guard reps > 0 else { return 0 }
        let wrongRate = min(max(Double(card.wrongCount) / Double(reps), 0), 1)
        let difficulty = (card.difficulty.clamped(to: 1...10) - 1) / 9
        let lapse = Double(min(card.lapses, 5)) / 5
        let miss = Double(min(card.miss, 5)) / 5
        var retrievability = 1.0
        if card.stability > 0, let last = card.lastReview {
            let days = max(now.timeIntervalSince(last), 0) / 86_400
            retrievability = fsrs.retrievability(elapsedDays: days, stability: card.stability)
        }
        return wrongRate * 2 + difficulty * 1.2 + lapse + miss * 0.5 + (1 - retrievability) * 0.8
    }

    static func isWeak(_ card: Card, now: Date = .now) -> Bool {
        card.isActive && card.reps >= 1 && weakScore(card, now: now) >= weakThreshold
    }

    /// Schwierige Woerter, die schwierigsten zuerst.
    static func weakCards(_ cards: [Card], now: Date = .now) -> [Card] {
        cards
            .filter { isWeak($0, now: now) }
            .sorted { weakScore($0, now: now) > weakScore($1, now: now) }
    }
}
