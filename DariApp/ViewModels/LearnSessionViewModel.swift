//
//  LearnSessionViewModel.swift
//  DariApp
//
//  Steuert einen laufenden Lerndurchgang: Warteschlange, aktuelle Karte,
//  aufgeloeste Abfragerichtung, Antwortbewertung, FSRS-Planung und das
//  Schreiben der Historie. Vollstaendig UI-unabhaengig und damit testbar.
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

    // MARK: Zustand

    private(set) var queue: [Card] = []
    private(set) var index = 0
    private(set) var isFlipped = false
    private(set) var answeredCount = 0
    private(set) var correctCount = 0
    private(set) var isFinished = false

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
    private let scheduler: ReviewScheduler
    private let allCards: [Card]
    private var questionStart = Date()
    private var rng = SystemRandomNumberGenerator()

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
        self.scheduler = ReviewScheduler(fsrs: fsrs)
        self.allCards = allCards

        self.queue = scheduler.buildQueue(
            from: candidates,
            limit: config.limit,
            generator: &rng
        )
        if queue.isEmpty {
            isFinished = true
        } else {
            prepareCurrent()
        }
    }

    // MARK: Aktuelle Karte

    var currentCard: Card? {
        guard index < queue.count else { return nil }
        return queue[index]
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
        queue.isEmpty ? 0 : Double(index) / Double(queue.count)
    }

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
        guard let card = currentCard else { return }
        let now = Date()
        let time = elapsed()

        let result = fsrs.schedule(card: card, rating: rating, reviewDate: now)
        card.stability = result.stability
        card.difficulty = result.difficulty
        card.state = result.state
        card.interval = result.intervalDays
        card.lastReview = now
        card.nextReview = result.due
        card.lastAnswerTime = time
        card.reps += 1
        if rating == .again {
            card.wrongCount += 1
            if card.state == .relearning { card.lapses += 1 }
        } else {
            card.correctCount += 1
            correctCount += 1
        }

        let log = ReviewLog(card: card, rating: rating, answerTime: time, mode: config.mode)
        context.insert(log)
        try? context.save()

        answeredCount += 1
    }

    private func advance() {
        index += 1
        if index >= queue.count {
            isFinished = true
        } else {
            prepareCurrent()
        }
    }

    private func elapsed() -> TimeInterval {
        Date().timeIntervalSince(questionStart)
    }

    // MARK: - Multiple-Choice-Distraktoren

    /// Baut vier plausible Optionen: eine korrekte plus drei Ablenker,
    /// bevorzugt aus Karten mit gemeinsamen Tags (aehnlicheres Vokabular).
    private func buildChoices(for card: Card) {
        let correct = answerIsPersian ? card.primaryPersian : card.primaryGerman

        let tagNames = Set(card.tags.map(\.name))
        let others = allCards.filter { $0.id != card.id }

        func answer(of c: Card) -> String {
            answerIsPersian ? c.primaryPersian : c.primaryGerman
        }

        // Bevorzugt gleiche Tags, dann alle uebrigen; Duplikate/Leere raus.
        let sameTag = others.filter { !tagNames.isDisjoint(with: Set($0.tags.map(\.name))) }
        let rest = others.filter { tagNames.isDisjoint(with: Set($0.tags.map(\.name))) }

        var pool = (sameTag.shuffled(using: &rng) + rest.shuffled(using: &rng))
            .map(answer)
            .filter { !$0.isEmpty && $0 != correct }

        var distractors: [String] = []
        for candidate in pool where distractors.count < 3 {
            if !distractors.contains(candidate) { distractors.append(candidate) }
        }
        pool.removeAll()

        var options = ([correct] + distractors).shuffled(using: &rng)
        // Falls zu wenig Karten existieren, mit dem korrekten Wert auffuellen
        // wird vermieden; stattdessen kleinere Auswahl zulassen.
        options = Array(Set(options))
        if !options.contains(correct) { options.append(correct) }
        options.shuffle(using: &rng)

        choices = options
        correctChoiceIndex = options.firstIndex(of: correct) ?? 0
    }
}
