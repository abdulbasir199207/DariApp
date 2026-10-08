//
//  ReviewScheduler.swift
//  DariApp
//
//  Waehlt aus einer Kartenmenge die zu lernende Reihenfolge.
//
//  Ziele (laut Spezifikation):
//  - gute Durchmischung, keine direkten Wiederholungen
//  - schwierige Karten haeufiger, leichte seltener
//  - ausgewogene Verteilung ueber Tags
//  - abwechslungsreiche Reihenfolge
//
//  Strategie: Ueberfaellige/neue Karten werden nach einer Prioritaet
//  gewichtet gemischt. Anschliessend sorgt ein Interleaving-Schritt dafuer,
//  dass nicht mehrere Karten desselben Tags direkt aufeinanderfolgen.
//

import Foundation

struct ReviewScheduler: Sendable {

    let fsrs: FSRS

    init(fsrs: FSRS = FSRS()) {
        self.fsrs = fsrs
    }

    /// Baut die Lern-Warteschlange fuer eine Session.
    /// - Parameters:
    ///   - cards: Kandidatenkarten (bereits nach Tag/Aktiv gefiltert).
    ///   - limit: Optionales Maximum (z. B. tägliches Lernziel).
    ///   - date: Bezugszeitpunkt fuer Faelligkeit.
    ///   - generator: Zufallsquelle (injizierbar fuer Tests).
    func buildQueue(
        from cards: [Card],
        limit: Int? = nil,
        date: Date = .now,
        generator: inout some RandomNumberGenerator
    ) -> [Card] {

        // 1) Nur aktive Karten; faellige und neue bevorzugen.
        let active = cards.filter(\.isActive)
        let due = active.filter { $0.isDue(asOf: date) }
        let pool = due.isEmpty ? active : due

        // 2) Prioritaet je Karte berechnen und gewichtet sortieren.
        let scored = pool.map { card in
            (card: card, priority: priority(for: card, date: date, generator: &generator))
        }
        let sorted = scored.sorted { $0.priority > $1.priority }.map(\.card)

        // 3) Nach Tags interleaven, damit keine Monotonie entsteht.
        let interleaved = interleaveByTag(sorted)

        if let limit, interleaved.count > limit {
            return Array(interleaved.prefix(limit))
        }
        return interleaved
    }

    // MARK: - Prioritaet

    /// Hoehere Werte = frueher lernen.
    /// Kombiniert Ueberfaelligkeit, Schwierigkeit und eine Zufallskomponente.
    private func priority(
        for card: Card,
        date: Date,
        generator: inout some RandomNumberGenerator
    ) -> Double {

        // Ueberfaelligkeit in Tagen (neue Karten hoch priorisiert).
        let overdue: Double
        if let next = card.nextReview {
            overdue = max(date.timeIntervalSince(next) / 86_400, 0)
        } else {
            overdue = 2.0 // neue Karte
        }

        // Zufallsrauschen fuer Abwechslung.
        let noise = Double.random(in: 0...1, using: &generator)

        // Gewichtung: Faelligkeit dominiert, Schwaeche (Fehlerquote, Schwierigkeit,
        // Rueckfaelle) erhoeht die Frequenz, Rauschen verhindert immer gleiche Reihenfolge.
        return overdue * 2.0 + Adaptive.weakScore(card, now: date, fsrs: fsrs) * 0.8 + noise
    }

    // MARK: - Tag-Interleaving

    /// Ordnet so um, dass moeglichst nicht zwei Karten mit identischem
    /// (fuehrendem) Tag direkt hintereinander stehen.
    private func interleaveByTag(_ cards: [Card]) -> [Card] {
        guard cards.count > 2 else { return cards }

        var remaining = cards
        var result: [Card] = []
        result.reserveCapacity(cards.count)

        while !remaining.isEmpty {
            let lastTag = result.last?.tags.first?.name
            // Suche die erste Karte, deren fuehrender Tag sich unterscheidet.
            if let idx = remaining.firstIndex(where: { $0.tags.first?.name != lastTag }) {
                result.append(remaining.remove(at: idx))
            } else {
                // Alle verbleibenden teilen den Tag -> Reihenfolge belassen.
                result.append(remaining.removeFirst())
            }
        }
        return result
    }
}
