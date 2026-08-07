//
//  ReviewLog.swift
//  DariApp
//
//  Historien-Eintrag je Wiederholung. Getrennt vom Kartenmodell gehalten,
//  damit Statistiken (Erfolgsquote, Antwortzeit, Verlauf, Streak) effizient
//  ueber alle Ereignisse berechnet werden koennen, ohne die Karte zu belasten.
//

import Foundation
import SwiftData

@Model
final class ReviewLog {

    var id: UUID = UUID()
    var date: Date = Date()

    /// FSRS-Bewertung dieser Antwort (Rohwert 1...4).
    var rating: FSRSRating = FSRSRating.good

    /// Gemessene Antwortzeit in Sekunden.
    var answerTime: TimeInterval = 0

    /// In welchem Modus wurde geantwortet.
    var mode: LearningMode = LearningMode.flip

    /// Referenz auf die Karte (optional, damit das Loeschen einer Karte
    /// die Historie nicht zwingend mitreisst – Nullify-Verhalten).
    @Relationship(deleteRule: .nullify)
    var card: Card?

    init(card: Card?, rating: FSRSRating, answerTime: TimeInterval, mode: LearningMode) {
        self.id = UUID()
        self.date = Date()
        self.card = card
        self.rating = rating
        self.answerTime = answerTime
        self.mode = mode
    }
}
