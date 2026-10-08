//
//  PracticeSessionViewModel.swift
//  DariApp
//
//  Steuert eine Uebungseinheit mit gemischten Aufgabentypen (Auswahl, Schreiben,
//  Zuordnung, Hoeren, Lueckentext, Satzbildung, Uebersetzen, Grammatik,
//  Aussprache). UI-unabhaengig; die Views lesen nur den Zustand.
//
//  Regeln (wie in der Web-Version):
//  - Auswahl, Schreiben, Hoeren und Lueckentext aus eigenen Karten aendern den
//    FSRS-Plan; Zuordnung und Aussprache nur die Schwaeche-Bewertung.
//  - Falsch beantwortete Aufgaben kommen einige Positionen spaeter noch einmal
//    als Uebung (aendert den Lernplan nicht, halbe Punkte).
//

import Foundation
import SwiftData
import Observation

/// Zustand der Zuordnungsaufgabe.
struct MatchState: Equatable {
    var round: MatchRound
    var selectedLeft: UUID?
    var selectedRight: UUID?
    var done: Set<UUID> = []
    var mistakes: [UUID: Int] = [:]
    var errors = 0
    var shake: (left: UUID, right: UUID)?
    var finished = false

    static func == (lhs: MatchState, rhs: MatchState) -> Bool {
        lhs.round == rhs.round && lhs.selectedLeft == rhs.selectedLeft && lhs.selectedRight == rhs.selectedRight
            && lhs.done == rhs.done && lhs.mistakes == rhs.mistakes && lhs.errors == rhs.errors
            && lhs.finished == rhs.finished && lhs.shake?.left == rhs.shake?.left && lhs.shake?.right == rhs.shake?.right
    }
}

/// Alles, was die Oberflaeche zur aktuellen Aufgabe braucht.
struct StepState {
    var choices: ChoiceSet?
    var selected: Int?
    var quality: AnswerQuality?
    var input = ""
    var cloze: ClozeData?
    var build: BuildData?
    var placed: [Int] = []          // Positionen in `build.tokens`
    var buildCorrect: Bool?
    var translate: TranslateData?
    var grammar: GrammarQuestion?
    var listen: ListenData?
    var match: MatchState?
    var recordedFile: String?       // Aussprache: eigene Aufnahme
    var isRecording = false
}

@MainActor
@Observable
final class PracticeSessionViewModel {

    let title: String
    private(set) var steps: [PracticeStep]
    private(set) var index = 0
    private(set) var isFinished = false
    private(set) var answeredCount = 0
    private(set) var correctCount = 0
    private(set) var xpGained = 0
    private(set) var weakFixed = 0
    var state = StepState()

    private let cards: [Card]
    private let context: ModelContext
    private let recorder: AnswerRecorder
    private let regenerate: (@MainActor () -> [PracticeStep])?
    private var stepStart = Date()
    @ObservationIgnored private var factory = ExerciseFactory(rng: SystemRandomNumberGenerator())

    let speech = SpeechService.shared
    let audio = AudioRecorder()

    init(
        title: String,
        steps: [PracticeStep],
        cards: [Card],
        context: ModelContext,
        regenerate: (@MainActor () -> [PracticeStep])? = nil
    ) {
        self.title = title
        self.steps = steps
        self.cards = cards
        self.context = context
        self.recorder = AnswerRecorder(context: context)
        self.regenerate = regenerate
        if steps.isEmpty { isFinished = true } else { prepare() }
    }

    // MARK: Zugriff

    var current: PracticeStep? { index < steps.count ? steps[index] : nil }
    var canRestart: Bool { regenerate != nil }
    var progress: Double { steps.isEmpty ? 0 : Double(index) / Double(steps.count) }
    var elapsed: TimeInterval { Date().timeIntervalSince(stepStart) }

    func cardByID(_ id: UUID) -> Card? { cards.first { $0.id == id } }

    /// Neue Einheit mit denselben Einstellungen.
    func restart() -> [PracticeStep]? { regenerate?() }

    // MARK: Vorbereitung

    private func prepare() {
        guard let step = current else { isFinished = true; return }
        stepStart = Date()
        state = StepState()
        let library = factory.library
        switch step.kind {
        case .choice(let id, let direction):
            guard let card = cardByID(id) else { return skip() }
            state.choices = factory.makeCardChoices(
                card: card, answerLanguage: direction == .germanToPersian ? .persian : .german, cards: cards.filter(\.isActive))
        case .write:
            if case .write(let id, _) = step.kind, cardByID(id) == nil { return skip() }
        case .match(let round):
            state.match = MatchState(round: round)
        case .listen(let id, let spoken):
            guard let card = cardByID(id) else { return skip() }
            state.listen = factory.makeListen(card: card, spoken: spoken, cards: cards.filter(\.isActive))
        case .cloze(let sentenceID, let language):
            guard let sentence = library.sentences.first(where: { $0.id == sentenceID }) else { return skip() }
            state.cloze = factory.makeCloze(sentence: sentence, language: language)
        case .cardCloze(let id):
            guard let card = cardByID(id), let data = factory.makeCardCloze(card: card, cards: cards) else { return skip() }
            state.cloze = data
        case .build(let sentenceID, let direction):
            guard let sentence = library.sentences.first(where: { $0.id == sentenceID }) else { return skip() }
            state.build = factory.makeBuild(sentence: sentence, direction: direction)
        case .translate(let sentenceID, let direction):
            guard let sentence = library.sentences.first(where: { $0.id == sentenceID }) else { return skip() }
            state.translate = factory.makeTranslate(sentence: sentence, direction: direction)
        case .grammar(let itemID):
            guard let item = library.grammar.first(where: { $0.id == itemID }) else { return skip() }
            state.grammar = factory.makeGrammar(item: item)
        case .speak(let id):
            if cardByID(id) == nil { return skip() }
        }
    }

    private func skip() {
        index += 1
        if index >= steps.count { isFinished = true } else { prepare() }
    }

    func next() {
        speech.stop()
        discardRecording()
        index += 1
        if index >= steps.count { isFinished = true; audio.stopPlayback() } else { prepare() }
    }

    // MARK: Verbuchen

    private func tally(_ log: ReviewLog) {
        answeredCount += 1
        if log.rating != .again { correctCount += 1 }
        xpGained += Gamification.xp(for: log)
        if log.wasWeak && log.rating.rawValue >= FSRSRating.good.rawValue { weakFixed += 1 }
    }

    private func requeueIfWrong(_ wrong: Bool) {
        guard wrong, let step = current, !step.isRetry else { return }
        ExerciseFactory<SystemRandomNumberGenerator>.requeue(&steps, after: index)
    }

    private func recordCard(_ id: UUID, rating: FSRSRating, mode: LearningMode, exercise: String, useFSRS: Bool = true) {
        guard let card = cardByID(id), let step = current else { return }
        let log = recorder.recordCard(
            card, rating: rating, time: elapsed, mode: mode, exercise: exercise,
            practice: step.isRetry, useFSRS: useFSRS)
        tally(log)
        context.saveReporting()
    }

    private func recordItem(_ id: String, ok: Bool, rating: FSRSRating = .good, exercise: String) {
        guard let step = current else { return }
        let log = recorder.recordItem(
            itemID: id, ok: ok, rating: rating, time: elapsed, exercise: exercise, practice: step.isRetry)
        tally(log)
        context.saveReporting()
    }

    // MARK: Auswahl (Multiple Choice, Hoeren, Luecke, Grammatik)

    func choose(_ i: Int) {
        guard state.selected == nil, let step = current else { return }
        state.selected = i
        func quality(_ set: ChoiceSet?) -> AnswerQuality { i == set?.correctIndex ? .perfect : .wrong }
        let fastLimit = 4.0
        switch step.kind {
        case .choice(let id, _):
            let q = quality(state.choices); state.quality = q
            recordCard(id, rating: q.rating(fast: elapsed < fastLimit), mode: .multipleChoice, exercise: "")
            requeueIfWrong(q == .wrong)
        case .listen(let id, _):
            let q = quality(state.listen?.choices); state.quality = q
            recordCard(id, rating: q.rating(fast: elapsed < 5), mode: .multipleChoice, exercise: "listen")
            requeueIfWrong(q == .wrong)
        case .cardCloze(let id):
            let q = quality(state.cloze?.choices); state.quality = q
            recordCard(id, rating: q.rating(fast: elapsed < fastLimit), mode: .multipleChoice, exercise: "ccloze")
            requeueIfWrong(q == .wrong)
        case .cloze(let sentenceID, _):
            let q = quality(state.cloze?.choices); state.quality = q
            recordItem(sentenceID, ok: q == .perfect, exercise: "cloze")
            requeueIfWrong(q == .wrong)
        case .grammar(let itemID):
            let q = quality(state.grammar?.choices); state.quality = q
            recordItem(itemID, ok: q == .perfect, exercise: "grammar")
            requeueIfWrong(q == .wrong)
        default:
            break
        }
        if let q = state.quality { Haptics.feedback(for: q) }
    }

    // MARK: Schreiben / Uebersetzen

    func submitText() {
        let text = state.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.quality == nil, !text.isEmpty, let step = current else { return }
        switch step.kind {
        case .write(let id, let direction):
            guard let card = cardByID(id) else { return }
            let persian = direction == .germanToPersian
            let q = AnswerChecker.evaluate(
                input: text, against: persian ? card.persianTranslations : card.germanTranslations, isPersian: persian)
            state.quality = q
            recordCard(id, rating: q.rating(fast: elapsed < 5), mode: .writing, exercise: "")
            requeueIfWrong(q == .wrong)
        case .translate(let sentenceID, _):
            guard let data = state.translate else { return }
            let q = AnswerChecker.evaluateSentence(
                input: text, against: data.solutions, isPersian: data.answerLanguage == .persian)
            state.quality = q
            recordItem(sentenceID, ok: q != .wrong, rating: q == .typo ? .hard : .good, exercise: "translate")
            requeueIfWrong(q == .wrong)
        default:
            return
        }
        if let q = state.quality { Haptics.feedback(for: q) }
    }

    // MARK: Satzbildung

    func place(_ position: Int) {
        guard state.buildCorrect == nil, !state.placed.contains(position) else { return }
        state.placed.append(position)
    }

    func unplace(_ position: Int) {
        guard state.buildCorrect == nil else { return }
        state.placed.removeAll { $0 == position }
    }

    func resetBuild() {
        guard state.buildCorrect == nil else { return }
        state.placed = []
    }

    func checkBuild() {
        guard state.buildCorrect == nil, let build = state.build, state.placed.count == build.tokens.count,
              case .build(let sentenceID, _)? = current?.kind else { return }
        let chosen = state.placed.map { build.tokens[$0].text }
        let ok = build.isCorrect(chosen)
        state.buildCorrect = ok
        state.quality = ok ? .perfect : .wrong
        recordItem(sentenceID, ok: ok, exercise: "build")
        requeueIfWrong(!ok)
        Haptics.feedback(for: ok ? .perfect : .wrong)
    }

    // MARK: Zuordnung

    func pickMatch(left: UUID? = nil, right: UUID? = nil) {
        guard var match = state.match, !match.finished else { return }
        if let id = left, !match.done.contains(id) { match.selectedLeft = id }
        if let id = right, !match.done.contains(id) { match.selectedRight = id }
        if let l = match.selectedLeft, let r = match.selectedRight {
            match.selectedLeft = nil; match.selectedRight = nil
            if l == r {
                match.done.insert(l)
                Haptics.tap()
            } else {
                match.mistakes[l, default: 0] += 1
                match.mistakes[r, default: 0] += 1
                match.errors += 1
                match.shake = (l, r)
                Haptics.error()
            }
        }
        if match.done.count == match.round.cardIDs.count && !match.finished {
            match.finished = true
            let per = elapsed / Double(max(match.round.cardIDs.count, 1))
            for id in match.round.cardIDs {
                guard let card = cardByID(id) else { continue }
                let rating: FSRSRating = (match.mistakes[id] ?? 0) > 0 ? .again : .good
                let log = recorder.recordCard(card, rating: rating, time: per, mode: .flip, exercise: "match", useFSRS: false)
                tally(log)
            }
            context.saveReporting()
        }
        state.match = match
    }

    /// Entfernt die kurze Wackel-Markierung nach einem Fehlversuch.
    func clearShake() {
        state.match?.shake = nil
    }

    // MARK: Aussprache

    func playReference(for id: UUID) {
        guard let card = cardByID(id) else { return }
        if card.hasAudio, let name = card.audioFileName, audio.exists(fileName: name) {
            audio.play(fileName: name)
        } else if speech.canSpeak(.persian) {
            speech.speak(card.primaryPersian, language: .persian)
        } else if speech.canSpeak(.german) {
            speech.speak(card.primaryGerman, language: .german)
        }
    }

    func toggleRecording() async {
        if state.isRecording {
            audio.stopRecording()
            state.isRecording = false
            return
        }
        discardRecording()
        if let name = await audio.startRecording() {
            state.recordedFile = name
            state.isRecording = true
        }
    }

    /// Spielt die Hoeraufgabe ab: eigene Aufnahme (Persisch) oder Sprachausgabe.
    func playListening() {
        guard let data = state.listen, let card = cardByID(data.cardID) else { return }
        if data.spoken == .persian, let name = card.audioFileName, audio.exists(fileName: name) {
            audio.play(fileName: name)
        } else {
            speech.speak(data.speakText, language: data.spoken)
        }
    }

    func playRecording() {
        if let name = state.recordedFile { audio.play(fileName: name) }
    }

    func rateSpeaking(good: Bool) {
        guard case .speak(let id)? = current?.kind else { return }
        recordCard(id, rating: good ? .good : .again, mode: .flip, exercise: "speak", useFSRS: false)
        next()
    }

    private func discardRecording() {
        if state.isRecording { audio.stopRecording(); state.isRecording = false }
        if let name = state.recordedFile { audio.deleteRecording(fileName: name); state.recordedFile = nil }
    }

    func leave() {
        speech.stop()
        discardRecording()
        audio.stopPlayback()
    }

    func finishEarly() {
        leave()
        isFinished = true
    }
}
