//
//  LearnSessionViewModel.swift
//  DariApp
//
//  Steuert einen laufenden Lerndurchgang: Warteschlange, aktuelle Karte,
//  aufgeloeste Abfragerichtung, Antwortbewertung, FSRS-Planung und das
//  Schreiben der Historie. Vollstaendig UI-unabhaengig und damit testbar.
//
//  Neu: Eine falsch beantwortete Karte kommt einige Positionen spaeter noch
//  einmal als Uebung dran (ohne den FSRS-Plan erneut zu aendern).
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class LearnSessionViewModel {

    // MARK: Konfiguration einer Session

    struct Configuration {
        var mode: LearningMode
        var direction: QueryDirection
        var limit: Int?
    }

    private struct Item {
        let card: Card
        let isRetry: Bool
    }

    // MARK: Zustand

    private var items: [Item] = []
    private(set) var index = 0
    private(set) var isFlipped = false
    private(set) var answeredCount = 0
    private(set) var correctCount = 0
    private(set) var isFinished = false
    private(set) var xpGained = 0
    private(set) var weakFixed = 0

    /// Aufgeloeste Richtung der aktuellen Karte (bei "gemischt" pro Karte).
    private(set) var currentDirection: ResolvedDirection = .germanToPersian

    /// Multiple-Choice-Optionen der aktuellen Karte (Antwort-Seite).
    private(set) var choices: [String] = []
    /// Index der korrekten Option in `choices`.
    private(set) var correctChoiceIndex = 0
    /// Vom Nutzer gewaehlte Option (nil = noch offen).
    private(set) var selectedChoiceIndex: Int?

    /// Ergebnis der letzten Schreib-/MC-Antwort (fuer visuelles Feedback).
    private(set) var lastQuality: AnswerQuality?

    let config: Configuration

    private let context: ModelContext
    private let fsrs: FSRS
    private let recorder: AnswerRecorder
    private let scheduler: ReviewScheduler
    private let allCards: [Card]
    private var questionStart = Date()
    @ObservationIgnored private var rng = SystemRandomNumberGenerator()
    @ObservationIgnored private var factory = ExerciseFactory(rng: SystemRandomNumberGenerator())

    // MARK: Init

    init(
        config: Configuration,
        candidates: [Card],
        allCards: [Card],
        context: ModelContext,
        fsrs: FSRS = FSRS()
    ) {
        self.config = config
        self.context = context
        self.fsrs = fsrs
        self.recorder = AnswerRecorder(context: context, fsrs: fsrs)
        self.scheduler = ReviewScheduler(fsrs: fsrs)
        self.allCards = allCards

        let queue = scheduler.buildQueue(
            from: candidates,
            limit: config.limit,
            generator: &rng
        )
        self.items = queue.map { Item(card: $0, isRetry: false) }
        if items.isEmpty {
            isFinished = true
        } else {
            prepareCurrent()
        }
    }

    // MARK: Aktuelle Karte

    var currentCard: Card? {
        guard index < items.count else { return nil }
        return items[index].card
    }

    /// Ist die aktuelle Karte eine Wiederholung nach einem Fehler?
    var isRetry: Bool {
        guard index < items.count else { return false }
        return items[index].isRetry
    }

    /// Text der abgefragten (Vorder-)Seite.
    var promptText: String {
        guard let card = currentCard else { return "" }
        return currentDirection == .germanToPersian ? card.primaryGerman : card.primaryPersian
    }

    /// Text der Loesungs-(Rueck-)Seite.
    var answerText: String {
        guard let card = currentCard else { return "" }
        return currentDirection == .germanToPersian ? card.primaryPersian : card.primaryGerman
    }

    /// Ist die Vorderseite persisch dargestellt?
    var promptIsPersian: Bool { currentDirection == .persianToGerman }
    /// Ist die Rueckseite persisch dargestellt (= Antwort in persischer Schrift)?
    var answerIsPersian: Bool { currentDirection == .germanToPersian }

    var progress: Double {
        items.isEmpty ? 0 : Double(index) / Double(items.count)
    }

    var totalCount: Int { items.count }

    // MARK: Interaktion – Modus 1 (Umdrehen)

    func flip() { isFlipped.toggle() }

    /// Selbsteinschaetzung im Umdreh-Modus.
    func rate(_ rating: FSRSRating) {
        applyRating(rating)
        advance()
    }

    // MARK: Interaktion – Modus 2 (Multiple Choice)

    func selectChoice(_ i: Int) {
        guard selectedChoiceIndex == nil else { return }
        selectedChoiceIndex = i
        let quality: AnswerQuality = (i == correctChoiceIndex) ? .perfect : .wrong
        lastQuality = quality
        let fast = elapsed() < 4
        applyRating(quality.rating(fast: fast))
    }

    // MARK: Interaktion – Modus 3 (Schreiben)

    func submitWriting(_ input: String) {
        guard let card = currentCard, lastQuality == nil else { return }
        let solutions = answerIsPersian ? card.persianTranslations : card.germanTranslations
        let quality = AnswerChecker.evaluate(input: input, against: solutions, isPersian: answerIsPersian)
        lastQuality = quality
        isFlipped = true
        let fast = elapsed() < 5
        applyRating(quality.rating(fast: fast))
    }

    /// Geht nach angezeigtem Feedback zur naechsten Karte.
    func continueAfterFeedback() { advance() }

    // MARK: - Interne Logik

    private func prepareCurrent() {
        guard let card = currentCard else { isFinished = true; return }
        isFlipped = false
        selectedChoiceIndex = nil
        lastQuality = nil
        currentDirection = config.direction.resolved(using: &rng)
        if config.mode == .multipleChoice {
            buildChoices(for: card)
        }
        questionStart = Date()
    }

    /// Wendet die FSRS-Planung an, aktualisiert Karte und schreibt Historie.
    private func applyRating(_ rating: FSRSRating) {
        guard index < items.count else { return }
        let item = items[index]
        let log = recorder.recordCard(
            item.card, rating: rating, time: elapsed(), mode: config.mode, practice: item.isRetry)
        context.saveReporting()

        answeredCount += 1
        if rating != .again { correctCount += 1 }
        xpGained += Gamification.xp(for: log)
        if log.wasWeak && rating.rawValue >= FSRSRating.good.rawValue { weakFixed += 1 }

        // Falsch beantwortet: einige Karten spaeter noch einmal uebungshalber.
        if rating == .again && !item.isRetry {
            let at = min(index + 1 + 3, items.count)
            items.insert(Item(card: item.card, isRetry: true), at: at)
        }
    }

    private func advance() {
        index += 1
        if index >= items.count {
            isFinished = true
        } else {
            prepareCurrent()
        }
    }

    private func elapsed() -> TimeInterval {
        Date().timeIntervalSince(questionStart)
    }

    // MARK: - Multiple-Choice-Distraktoren

    /// Baut bis zu vier plausible Optionen: eine korrekte plus Ablenker,
    /// bevorzugt aus Karten mit gemeinsamen Tags (aehnlicheres Vokabular).
    private func buildChoices(for card: Card) {
        let set = factory.makeCardChoices(
            card: card, answerLanguage: answerIsPersian ? .persian : .german, cards: allCards)
        choices = set.options
        correctChoiceIndex = set.correctIndex
    }
}
