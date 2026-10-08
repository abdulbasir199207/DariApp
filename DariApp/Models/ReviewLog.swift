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

    /// Uebungstyp ausserhalb der drei Vokabel-Modi ("match", "listen", "cloze",
    /// "build", "translate", "grammar", "speak"); leer bei Umdrehen/Auswahl/Schreiben.
    var exercise: String = ""

    /// Kennung von Satz- oder Grammatikaufgaben (statt einer Karte).
    var itemID: String?

    /// Uebungswiederholung nach einem Fehler: zaehlt nicht fuers Tagesziel,
    /// aendert den FSRS-Termin nicht und gibt nur halbe Punkte.
    var isPractice: Bool = false

    /// Das Wort galt vor dieser Antwort als schwierig.
    var wasWeak: Bool = false

    /// Referenz auf die Karte (optional, damit das Loeschen einer Karte
    /// die Historie nicht zwingend mitreisst – Nullify-Verhalten).
    @Relationship(deleteRule: .nullify)
    var card: Card?

    init(
        card: Card?,
        rating: FSRSRating,
        answerTime: TimeInterval,
        mode: LearningMode,
        exercise: String = "",
        itemID: String? = nil,
        isPractice: Bool = false,
        wasWeak: Bool = false,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.card = card
        self.rating = rating
        self.answerTime = answerTime
        self.mode = mode
        self.exercise = exercise
        self.itemID = itemID
        self.isPractice = isPractice
        self.wasWeak = wasWeak
    }
}
