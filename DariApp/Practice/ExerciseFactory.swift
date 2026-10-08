//
//  ExerciseFactory.swift
//  DariApp
//
//  Aufgaben-Generatoren und Uebungsplaene. Rein (ohne UI) und mit
//  austauschbarem Zufallsgenerator – dadurch voll testbar. Logik entspricht
//  der Web-Version (60-games.js).
//

import Foundation

// MARK: - Datentypen

struct ChoiceSet: Sendable, Equatable {
    var options: [String]
    var correctIndex: Int
}

struct MatchRound: Sendable, Equatable {
    var cardIDs: [UUID]
    var left: [UUID]
    var right: [UUID]
    var direction: ResolvedDirection
}

struct ClozeData: Sendable, Equatable {
    var sentenceID: String?
    var cardID: UUID?
    var language: ExerciseLanguage
    var blankIndex: Int
    var answer: String
    var trail: String
    var tokens: [String?]
    var choices: ChoiceSet
    var hint: String
    var hintLanguage: ExerciseLanguage
    var full: String
    var transliteration: String
}

struct BuildToken: Identifiable, Sendable, Equatable {
    let id: Int
    let text: String
}

struct BuildData: Sendable, Equatable {
    var sentenceID: String
    var tokens: [BuildToken]
    var solution: [String]
    var alternatives: [[String]]
    var prompt: String
    var promptLanguage: ExerciseLanguage
    var answerLanguage: ExerciseLanguage
    var full: String
    var transliteration: String

    /// Pruft eine gelegte Wortfolge (Gross-/Kleinschreibung und Satzzeichen zaehlen nicht).
    func isCorrect(_ chosen: [String]) -> Bool {
        let isPersian = answerLanguage == .persian
        func norm(_ words: [String]) -> String {
            words.map { AnswerChecker.normalize($0, isPersian: isPersian) }.joined(separator: " ")
        }
        let candidate = norm(chosen)
        return ([solution] + alternatives).contains { norm($0) == candidate }
    }
}

struct TranslateData: Sendable, Equatable {
    var sentenceID: String
    var prompt: String
    var promptLanguage: ExerciseLanguage
    var answerLanguage: ExerciseLanguage
    var solutions: [String]
    var transliteration: String
}

struct GrammarQuestion: Sendable, Equatable {
    var itemID: String
    var language: ExerciseLanguage
    var topic: String
    var question: String
    var choices: ChoiceSet
    var explanation: String
    var explanationPersian: String
}

struct ListenData: Sendable, Equatable {
    var cardID: UUID
    var spoken: ExerciseLanguage
    var speakText: String
    var choices: ChoiceSet
    var answerLanguage: ExerciseLanguage
}

/// Eine Aufgabe in einer Uebungseinheit.
enum PracticeStepKind: Sendable, Equatable {
    case choice(cardID: UUID, direction: ResolvedDirection)
    case write(cardID: UUID, direction: ResolvedDirection)
    case match(MatchRound)
    case listen(cardID: UUID, spoken: ExerciseLanguage)
    case cloze(sentenceID: String, language: ExerciseLanguage)
    case cardCloze(cardID: UUID)
    case build(sentenceID: String, direction: ResolvedDirection)
    case translate(sentenceID: String, direction: ResolvedDirection)
    case grammar(itemID: String)
    case speak(cardID: UUID)
}

struct PracticeStep: Sendable, Equatable {
    var kind: PracticeStepKind
    /// Wiederholung nach einem Fehler (nur Uebung, aendert den Lernplan nicht).
    var isRetry = false
    /// Das Wort galt zu Beginn als schwierig.
    var isWeak = false
}

/// Seed-faehiger Zufallsgenerator (SplitMix64) – fuer reproduzierbare Tests.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Fabrik

@MainActor
struct ExerciseFactory<R: RandomNumberGenerator> {

    var rng: R
    let library: ContentLibrary

    init(rng: R, library: ContentLibrary = .shared) {
        self.rng = rng
        self.library = library
    }

    private static func key(_ text: String) -> String { AnswerChecker.normalize(text, isPersian: true) }

    // MARK: Auswahl

    /// Richtige Antwort plus bis zu n−1 Ablenker aus `pool` (ohne Duplikate und Synonyme).
    mutating func makeChoices(correct: String, pool: [String], exclude: [String] = [], count n: Int = 4) -> ChoiceSet {
        var excluded = Set(([correct] + exclude).map(Self.key))
        var distractors: [String] = []
        for candidate in pool.shuffled(using: &rng) {
            let k = Self.key(candidate)
            if candidate.isEmpty || excluded.contains(k) { continue }
            excluded.insert(k)
            distractors.append(candidate)
            if distractors.count >= n - 1 { break }
        }
        let options = ([correct] + distractors).shuffled(using: &rng)
        return ChoiceSet(options: options, correctIndex: options.firstIndex(of: correct) ?? 0)
    }

    /// Multiple Choice fuer eine Karte; bevorzugt Ablenker mit gemeinsamen Tags.
    mutating func makeCardChoices(card: Card, answerLanguage: ExerciseLanguage, cards: [Card]) -> ChoiceSet {
        let persian = answerLanguage == .persian
        func answer(_ c: Card) -> String { persian ? c.primaryPersian : c.primaryGerman }
        let correct = answer(card)
        let own = persian ? card.persianTranslations : card.germanTranslations
        let tagNames = Set(card.tags.map(\.name))
        let others = cards.filter { $0.id != card.id }
        let sameTag = others.filter { !tagNames.isDisjoint(with: Set($0.tags.map(\.name))) }.shuffled(using: &rng)
        let rest = others.filter { tagNames.isDisjoint(with: Set($0.tags.map(\.name))) }.shuffled(using: &rng)
        let pool = (sameTag + rest).map(answer).filter { !$0.isEmpty }
        let base = makeChoices(correct: correct, pool: pool, exclude: own)
        if base.options.count >= 4 { return base }
        // Zu wenige Karten: Reserve aus der Satzbibliothek.
        return makeChoices(correct: correct, pool: pool + library.words(answerLanguage, positions: "N"), exclude: own)
    }

    // MARK: Zuordnung

    /// Waehlt bis zu n Karten mit eindeutigen Woertern.
    func makeMatchRound(candidates: [Card], count n: Int = 5) -> [Card] {
        var picked: [Card] = []
        var seenGerman = Set<String>(), seenPersian = Set<String>()
        for card in candidates {
            let de = card.primaryGerman, fa = card.primaryPersian
            if de.isEmpty || fa.isEmpty { continue }
            let kd = AnswerChecker.normalize(de, isPersian: false), kf = Self.key(fa)
            if seenGerman.contains(kd) || seenPersian.contains(kf) { continue }
            seenGerman.insert(kd); seenPersian.insert(kf)
            picked.append(card)
            if picked.count >= n { break }
        }
        return picked
    }

    // MARK: Luckentext

    /// Uebernimmt die Gross-/Kleinschreibung des ersten Buchstabens von `reference`.
    static func matchCase(_ token: String, reference: String) -> String {
        guard let first = token.first, let ref = reference.first else { return token }
        let upper = String(ref) != String(ref).lowercased()
        return (upper ? String(first).uppercased() : String(first).lowercased()) + token.dropFirst()
    }

    /// Lueckentext aus der Satzbibliothek. `language`: Sprache des Satzes mit Luecke.
    mutating func makeCloze(sentence: Sentence, language: ExerciseLanguage) -> ClozeData {
        let tokens = sentence.tokens(language)
        let pos = sentence.positions(language)
        let blankChars = Set(library.blankPos)
        let allowed = sentence.blanks(language)
            ?? tokens.indices.filter { $0 < pos.count && blankChars.contains(pos[$0]) }
        let index = allowed.randomElement(using: &rng) ?? 0
        let answer = tokens[index]
        let wanted = index < pos.count ? pos[index] : "N"

        var same: [String] = [], any: [String] = []
        for other in library.sentences where other.id != sentence.id {
            let toks = other.tokens(language), ps = other.positions(language)
            for (i, token) in toks.enumerated() where i < ps.count && blankChars.contains(ps[i]) {
                let candidate = language == .german ? Self.matchCase(token, reference: answer) : token
                if ps[i] == wanted { same.append(candidate) } else { any.append(candidate) }
            }
        }
        var choices = makeChoices(correct: answer, pool: same)
        if choices.options.count < 4 { choices = makeChoices(correct: answer, pool: same + any) }
        let hintLanguage: ExerciseLanguage = language == .persian ? .german : .persian
        return ClozeData(
            sentenceID: sentence.id, cardID: nil, language: language, blankIndex: index, answer: answer, trail: "",
            tokens: tokens.enumerated().map { $0.offset == index ? nil : $0.element },
            choices: choices, hint: sentence.text(hintLanguage), hintLanguage: hintLanguage,
            full: sentence.text(language), transliteration: sentence.transliteration)
    }

    /// Lueckentext aus dem Beispielsatz einer eigenen Karte (nil, wenn das Wort im Satz fehlt).
    mutating func makeCardCloze(card: Card, cards: [Card]) -> ClozeData? {
        let sentence = card.examplePersian.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentence.isEmpty else { return nil }
        let words = sentence.split(whereSeparator: \.isWhitespace).map(String.init)
        let keys = card.persianTranslations.map(Self.key)
        guard let index = words.firstIndex(where: { keys.contains(Self.key($0)) }) else { return nil }
        let raw = words[index]
        let edge = CharacterSet(charactersIn: ".,;:!?…«»()\"'،؛؟").union(.whitespaces)
        let answer = raw.trimmingCharacters(in: edge)
        guard !answer.isEmpty else { return nil }
        let trail: String = {
            guard let range = raw.range(of: answer) else { return "" }
            return String(raw[range.upperBound...])
        }()
        let pool = cards.filter { $0.id != card.id }.map(\.primaryPersian).filter { !$0.isEmpty }
        var choices = makeChoices(correct: answer, pool: pool, exclude: card.persianTranslations)
        if choices.options.count < 4 {
            choices = makeChoices(correct: answer, pool: pool + library.words(.persian, positions: "N"), exclude: card.persianTranslations)
        }
        let hint = card.exampleGerman.isEmpty ? card.primaryGerman : card.exampleGerman
        return ClozeData(
            sentenceID: nil, cardID: card.id, language: .persian, blankIndex: index, answer: answer, trail: trail,
            tokens: words.enumerated().map { $0.offset == index ? nil : $0.element },
            choices: choices, hint: hint, hintLanguage: .german, full: sentence, transliteration: "")
    }

    // MARK: Satzbildung / Uebersetzen

    mutating func makeBuild(sentence: Sentence, direction: ResolvedDirection) -> BuildData {
        let toPersian = direction == .germanToPersian
        let answerLanguage: ExerciseLanguage = toPersian ? .persian : .german
        let solution = sentence.tokens(answerLanguage)
        let items = solution.enumerated().map { BuildToken(id: $0.offset, text: $0.element) }
        var shuffled = items.shuffled(using: &rng)
        if solution.count > 1, shuffled.enumerated().allSatisfy({ $0.element.id == $0.offset }) { shuffled.reverse() }
        return BuildData(
            sentenceID: sentence.id, tokens: shuffled, solution: solution,
            alternatives: toPersian ? sentence.persianAlternatives.map { $0.split(separator: " ").map(String.init) } : [],
            prompt: toPersian ? sentence.german : sentence.persian,
            promptLanguage: toPersian ? .german : .persian, answerLanguage: answerLanguage,
            full: sentence.text(answerLanguage), transliteration: sentence.transliteration)
    }

    func makeTranslate(sentence: Sentence, direction: ResolvedDirection) -> TranslateData {
        let toPersian = direction == .germanToPersian
        let end = sentence.isQuestion ? "؟" : "."
        let extra = toPersian ? sentence.persianAlternatives.map { $0 + end } : []
        return TranslateData(
            sentenceID: sentence.id, prompt: toPersian ? sentence.german : sentence.persian,
            promptLanguage: toPersian ? .german : .persian, answerLanguage: toPersian ? .persian : .german,
            solutions: [toPersian ? sentence.persian : sentence.german] + extra, transliteration: sentence.transliteration)
    }

    // MARK: Grammatik / Hoeren

    mutating func makeGrammar(item: GrammarItem) -> GrammarQuestion {
        let options = item.answers.shuffled(using: &rng)
        let correct = item.answers.first ?? ""
        return GrammarQuestion(
            itemID: item.id, language: item.exerciseLanguage, topic: item.topic, question: item.question,
            choices: ChoiceSet(options: options, correctIndex: options.firstIndex(of: correct) ?? 0),
            explanation: item.explanation, explanationPersian: item.explanationPersian)
    }

    /// `spoken` .german: Deutsch hoeren, Persisch waehlen · .persian: Persisch hoeren, Deutsch waehlen.
    mutating func makeListen(card: Card, spoken: ExerciseLanguage, cards: [Card]) -> ListenData {
        let answerLanguage: ExerciseLanguage = spoken == .german ? .persian : .german
        let text = spoken == .persian ? card.primaryPersian : card.primaryGerman
        return ListenData(
            cardID: card.id, spoken: spoken, speakText: text,
            choices: makeCardChoices(card: card, answerLanguage: answerLanguage, cards: cards),
            answerLanguage: answerLanguage)
    }

    // MARK: Plaene

    mutating func resolve(_ direction: QueryDirection) -> ResolvedDirection {
        direction.resolved(using: &rng)
    }

    /// Schwache zuerst, dann faellige, dann der Rest (jeweils gemischt).
    mutating func gameCandidates(cards: [Card], now: Date = .now) -> [Card] {
        let active = cards.filter(\.isActive)
        let weak = Adaptive.weakCards(active, now: now).shuffled(using: &rng)
        let weakIDs = Set(weak.map(\.id))
        let due = active.filter { $0.isDue(asOf: now) && !weakIDs.contains($0.id) }.shuffled(using: &rng)
        let dueIDs = Set(due.map(\.id))
        let rest = active.filter { !weakIDs.contains($0.id) && !dueIDs.contains($0.id) }.shuffled(using: &rng)
        return weak + due + rest
    }

    mutating func planWeak(cards: [Card], direction: QueryDirection, limit: Int = 12) -> [PracticeStep] {
        let list = Array(Adaptive.weakCards(cards).prefix(limit))
        let useChoice = cards.count >= 4
        var steps: [PracticeStep] = []
        for (i, card) in list.enumerated() {
            let dir = resolve(direction)
            let kind: PracticeStepKind = (useChoice && i % 2 == 0)
                ? .choice(cardID: card.id, direction: dir) : .write(cardID: card.id, direction: dir)
            steps.append(PracticeStep(kind: kind, isWeak: true))
        }
        return steps
    }

    mutating func planMatch(cards: [Card], rounds: Int = 3, direction: QueryDirection) -> [PracticeStep] {
        var steps: [PracticeStep] = []
        var pool = gameCandidates(cards: cards)
        for _ in 0..<rounds {
            let pick = makeMatchRound(candidates: pool, count: 5)
            if pick.count < 3 { break }
            let ids = pick.map(\.id)
            let round = MatchRound(
                cardIDs: ids, left: ids.shuffled(using: &rng), right: ids.shuffled(using: &rng),
                direction: resolve(direction))
            steps.append(PracticeStep(kind: .match(round)))
            let pickedIDs = Set(ids)
            pool = pool.filter { !pickedIDs.contains($0.id) } + pick
        }
        return steps
    }

    mutating func planListen(
        cards: [Card], direction: QueryDirection, count: Int = 10,
        canSpeakPersian: Bool, canSpeakGerman: Bool
    ) -> [PracticeStep] {
        var steps: [PracticeStep] = []
        for card in gameCandidates(cards: cards) {
            if steps.count >= count { break }
            var spoken: ExerciseLanguage
            switch direction {
            case .germanToPersian: spoken = .german
            case .persianToGerman: spoken = .persian
            case .mixed: spoken = Bool.random(using: &rng) ? .german : .persian
            }
            let canPersian = canSpeakPersian || card.hasAudio
            if spoken == .persian && !canPersian { spoken = .german }
            if spoken == .german && !canSpeakGerman {
                if canPersian { spoken = .persian } else { continue }
            }
            steps.append(PracticeStep(kind: .listen(cardID: card.id, spoken: spoken), isWeak: Adaptive.isWeak(card)))
        }
        return steps
    }

    /// Waehlt n Elemente: erst faellige/schwache, dann neue, dann der Rest.
    mutating func pick<T: Identifiable>(_ items: [T], stats: [String: ItemStat], count: Int, now: Date = .now) -> [T] where T.ID == String {
        let scored: [(item: T, score: Double)] = items.map { item in
            let p: Double
            if let s = stats[item.id] {
                if s.due <= now {
                    let total = max(s.okCount + s.badCount, 1)
                    p = 2 + Double(6 - s.box) * 0.3 + Double(s.badCount) / Double(total) + Double.random(in: 0..<0.3, using: &rng)
                } else {
                    p = Double.random(in: 0..<0.4, using: &rng)
                }
            } else {
                p = 1.5 + Double.random(in: 0..<0.5, using: &rng)
            }
            return (item, p)
        }
        return scored.sorted { $0.score > $1.score }.prefix(count).map(\.item)
    }

    enum SentenceExercise { case cloze, build, translate }

    mutating func planSentences(
        _ type: SentenceExercise, stats: [String: ItemStat], count: Int = 8, direction: QueryDirection
    ) -> [PracticeStep] {
        pick(library.sentences, stats: stats, count: count).map { sentence in
            let dir = resolve(direction)
            switch type {
            case .cloze: return PracticeStep(kind: .cloze(sentenceID: sentence.id, language: dir == .germanToPersian ? .persian : .german))
            case .build: return PracticeStep(kind: .build(sentenceID: sentence.id, direction: dir))
            case .translate: return PracticeStep(kind: .translate(sentenceID: sentence.id, direction: dir))
            }
        }
    }

    /// Lueckentext-Folge: bis zu 1/3 aus eigenen Beispielsaetzen, Rest aus der Bibliothek.
    mutating func planCloze(cards: [Card], stats: [String: ItemStat], count: Int = 10, direction: QueryDirection) -> [PracticeStep] {
        let mineCandidates = cards.filter { $0.isActive && !$0.examplePersian.isEmpty }
        var mine: [PracticeStep] = []
        for card in mineCandidates.shuffled(using: &rng) where mine.count < count / 3 {
            if makeCardCloze(card: card, cards: cards) != nil { mine.append(PracticeStep(kind: .cardCloze(cardID: card.id))) }
        }
        let lib = planSentences(.cloze, stats: stats, count: count - mine.count, direction: direction)
        return (lib + mine).shuffled(using: &rng)
    }

    mutating func planGrammar(language: ExerciseLanguage, topic: String?, stats: [String: ItemStat], count: Int = 10) -> [PracticeStep] {
        let pool = library.grammar.filter { $0.exerciseLanguage == language && (topic == nil || $0.topic == topic) }
        return pick(pool, stats: stats, count: count).map { PracticeStep(kind: .grammar(itemID: $0.id)) }
    }

    mutating func planSpeak(cards: [Card], count: Int = 8) -> [PracticeStep] {
        gameCandidates(cards: cards).prefix(count).map { PracticeStep(kind: .speak(cardID: $0.id)) }
    }

    /// „5-Minuten-Spiel": abwechslungsreiche Mischung (~12 Aufgaben).
    mutating func planMix(
        cards: [Card], stats: [String: ItemStat], direction: QueryDirection,
        canSpeakPersian: Bool, canSpeakGerman: Bool
    ) -> [PracticeStep] {
        let active = cards.filter(\.isActive)
        var steps: [PracticeStep] = []
        if active.count >= 3 { steps += planMatch(cards: active, rounds: 1, direction: direction) }
        let vocab = Array(gameCandidates(cards: active).prefix(6))
        for (i, card) in vocab.enumerated() {
            let dir = resolve(direction)
            let kind: PracticeStepKind = i % 3 == 2 ? .write(cardID: card.id, direction: dir) : .choice(cardID: card.id, direction: dir)
            steps.append(PracticeStep(kind: kind, isWeak: Adaptive.isWeak(card)))
        }
        steps += planListen(cards: active, direction: direction, count: 2, canSpeakPersian: canSpeakPersian, canSpeakGerman: canSpeakGerman)
        steps += planCloze(cards: cards, stats: stats, count: 2, direction: direction)
        steps += planSentences(.build, stats: stats, count: 1, direction: direction)
        steps += planGrammar(language: .persian, topic: nil, stats: stats, count: 2)
        return steps
    }

    /// Nach einem Fehler: dieselbe Aufgabe wenige Positionen spaeter als Uebung wiederholen.
    static func requeue(_ steps: inout [PracticeStep], after index: Int, gap: Int = 3) {
        var copy = steps[index]
        copy.isRetry = true
        steps.insert(copy, at: min(index + 1 + gap, steps.count))
    }
}
