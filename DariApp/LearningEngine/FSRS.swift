//
//  FSRS.swift
//  DariApp
//
//  Implementierung des Free Spaced Repetition Scheduler (FSRS 4.5).
//
//  FSRS modelliert das Gedaechtnis ueber zwei Groessen je Karte:
//  - stability (S): Zeit in Tagen, bis die Abrufwahrscheinlichkeit auf
//    das Zielniveau faellt.
//  - difficulty (D): intrinsische Schwierigkeit der Karte (1...10).
//
//  Aus S und dem gewuenschten Retention-Ziel wird das naechste
//  Wiederholungsintervall berechnet. Der Algorithmus ist rein funktional
//  und dadurch vollstaendig unit-testbar (keine Seiteneffekte, kein State).
//
//  Referenz: https://github.com/open-spaced-repetition/fsrs4anki (Wiki)
//

import Foundation

/// Ergebnis einer FSRS-Planung – die neuen Gedaechtniswerte plus Termin.
struct FSRSScheduling: Sendable, Equatable {
    var stability: Double
    var difficulty: Double
    var state: CardState
    /// Intervall in Tagen bis zur naechsten Wiederholung.
    var intervalDays: Int
    /// Konkreter Faelligkeitszeitpunkt.
    var due: Date
}

struct FSRS: Sendable {

    let parameters: FSRSParameters

    init(parameters: FSRSParameters = .default) {
        self.parameters = parameters
    }

    // FSRS-Kurvenkonstanten (Potenz-Vergessenskurve).
    private static let decay: Double = -0.5
    private static let factor: Double = 19.0 / 81.0

    // MARK: - Oeffentliche API

    /// Plant eine Karte nach einer Bewertung neu.
    ///
    /// - Parameters:
    ///   - card: Aktuelle Karte (deren S/D/state gelesen werden).
    ///   - rating: Die abgegebene Bewertung.
    ///   - reviewDate: Zeitpunkt der Wiederholung (Default: jetzt).
    /// - Returns: Neue Gedaechtniswerte und Termin.
    func schedule(card: Card, rating: FSRSRating, reviewDate: Date = .now) -> FSRSScheduling {
        let elapsedDays = elapsedDays(for: card, reviewDate: reviewDate)
        return schedule(
            stability: card.stability,
            difficulty: card.difficulty,
            state: card.state,
            elapsedDays: elapsedDays,
            rating: rating,
            reviewDate: reviewDate
        )
    }

    /// Reine Rechenfunktion – ohne Modellabhaengigkeit, ideal fuer Tests.
    func schedule(
        stability: Double,
        difficulty: Double,
        state: CardState,
        elapsedDays: Double,
        rating: FSRSRating,
        reviewDate: Date = .now
    ) -> FSRSScheduling {

        let newDifficulty: Double
        let newStability: Double
        let newState: CardState

        switch state {
        case .new:
            // Erste Begegnung: Initialwerte aus den Parametern.
            newDifficulty = initialDifficulty(rating)
            newStability = initialStability(rating)
            newState = (rating == .again) ? .learning : .review

        case .learning, .relearning, .review:
            let retrievability = self.retrievability(elapsedDays: elapsedDays, stability: stability)
            newDifficulty = nextDifficulty(difficulty, rating: rating)

            if rating == .again {
                newStability = forgetStability(
                    difficulty: newDifficulty,
                    stability: stability,
                    retrievability: retrievability
                )
                newState = .relearning
            } else {
                newStability = recallStability(
                    difficulty: newDifficulty,
                    stability: stability,
                    retrievability: retrievability,
                    rating: rating
                )
                newState = .review
            }
        }

        let clampedStability = max(newStability, 0.1)
        let interval = intervalDays(stability: clampedStability)
        let due = Calendar.current.date(byAdding: .day, value: interval, to: reviewDate) ?? reviewDate

        return FSRSScheduling(
            stability: clampedStability,
            difficulty: newDifficulty.clamped(to: 1...10),
            state: newState,
            intervalDays: interval,
            due: due
        )
    }

    /// Abrufwahrscheinlichkeit R(t) nach `elapsedDays` bei gegebener Stabilitaet.
    func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        let base = 1 + Self.factor * elapsedDays / stability
        return pow(base, Self.decay)
    }

    // MARK: - Intervall

    /// Intervall in Tagen fuer eine gegebene Stabilitaet und das Retention-Ziel.
    private func intervalDays(stability: Double) -> Int {
        let retention = parameters.requestRetention
        let raw = stability / Self.factor * (pow(retention, 1 / Self.decay) - 1)
        let rounded = Int(raw.rounded())
        return min(max(rounded, 1), parameters.maximumIntervalDays)
    }

    // MARK: - Schwierigkeit

    private func initialDifficulty(_ rating: FSRSRating) -> Double {
        let w = parameters.weights
        let d = w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1
        return d.clamped(to: 1...10)
    }

    private func nextDifficulty(_ difficulty: Double, rating: FSRSRating) -> Double {
        let w = parameters.weights
        // Lineare Daempfung Richtung Extremwerte + Mittelwert-Rueckkehr zu D0(easy).
        let delta = -w[6] * Double(rating.rawValue - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        let meanReverted = w[7] * initialDifficulty(.easy) + (1 - w[7]) * damped
        return meanReverted.clamped(to: 1...10)
    }

    // MARK: - Stabilitaet

    private func initialStability(_ rating: FSRSRating) -> Double {
        let w = parameters.weights
        return max(w[rating.rawValue - 1], 0.1)
    }

    /// Stabilitaet nach erfolgreichem Abruf (good/easy/hard).
    private func recallStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: FSRSRating
    ) -> Double {
        let w = parameters.weights
        let hardPenalty = (rating == .hard) ? w[15] : 1.0
        let easyBonus = (rating == .easy) ? w[16] : 1.0
        let factor = exp(w[8])
            * (11 - difficulty)
            * pow(stability, -w[9])
            * (exp(w[10] * (1 - retrievability)) - 1)
            * hardPenalty
            * easyBonus
        return stability * (1 + factor)
    }

    /// Stabilitaet nach Vergessen (again).
    private func forgetStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double
    ) -> Double {
        let w = parameters.weights
        return w[11]
            * pow(difficulty, -w[12])
            * (pow(stability + 1, w[13]) - 1)
            * exp(w[14] * (1 - retrievability))
    }

    // MARK: - Hilfen

    private func elapsedDays(for card: Card, reviewDate: Date) -> Double {
        guard let last = card.lastReview else { return 0 }
        let seconds = reviewDate.timeIntervalSince(last)
        return max(seconds / 86_400, 0)
    }
}

// MARK: - Utility

extension Comparable {
    /// Beschraenkt einen Wert auf den geschlossenen Bereich.
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
