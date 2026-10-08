//
//  ContentLibrary.swift
//  DariApp
//
//  Eingebaute Uebungsinhalte (Saetze + Grammatik). Die Daten liegen in
//  `zara-content.json` und werden aus derselben Quelle erzeugt wie in der
//  Web-Version (WebApp/tools/export-content.mjs) – beide Apps ueben dasselbe.
//
//  Wortarten je Token (germanPos/persianPos):
//  P Pronomen · N Nomen · V Verb · A Adjektiv · D Adverb/Frage · R Praeposition · X Sonstiges
//

import Foundation

/// Sprache eines Textes.
enum ExerciseLanguage: String, Sendable, Codable {
    case german = "de"
    case persian = "fa"
}

struct Sentence: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let category: String
    let level: Int
    let isQuestion: Bool
    let germanTokens: [String]
    let persianTokens: [String]
    let german: String
    let persian: String
    let transliteration: String
    let germanPos: String
    let persianPos: String
    let germanBlanks: [Int]?
    let persianBlanks: [Int]?
    let persianAlternatives: [String]

    func tokens(_ language: ExerciseLanguage) -> [String] { language == .persian ? persianTokens : germanTokens }
    func positions(_ language: ExerciseLanguage) -> [Character] { Array(language == .persian ? persianPos : germanPos) }
    func text(_ language: ExerciseLanguage) -> String { language == .persian ? persian : german }
    func blanks(_ language: ExerciseLanguage) -> [Int]? { language == .persian ? persianBlanks : germanBlanks }
    var endMark: (german: String, persian: String) { isQuestion ? ("?", "؟") : (".", ".") }
}

struct GrammarItem: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let language: String          // "fa" oder "de"
    let topic: String
    let question: String
    /// Antworten – die ERSTE ist die richtige (wird beim Abfragen gemischt).
    let answers: [String]
    let explanation: String
    let explanationPersian: String

    var exerciseLanguage: ExerciseLanguage { language == "fa" ? .persian : .german }
}

/// Hilfsklasse, um das Bundle der App-Module zu finden (auch im Test-Host).
final class ContentBundleToken {}

struct ContentLibrary: Codable, Sendable {

    let version: Int
    let blankPos: String
    let sentences: [Sentence]
    let grammar: [GrammarItem]

    /// Geladene Bibliothek (leer, falls die Datei fehlt – die App bleibt benutzbar).
    static let shared: ContentLibrary = load()

    static func load(bundle: Bundle = Bundle(for: ContentBundleToken.self)) -> ContentLibrary {
        guard let url = bundle.url(forResource: "zara-content", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? JSONDecoder().decode(ContentLibrary.self, from: data)
        else { return ContentLibrary(version: 0, blankPos: "NVAD", sentences: [], grammar: []) }
        return library
    }

    func grammarTopics(for language: ExerciseLanguage) -> [String] {
        var seen = Set<String>(), topics: [String] = []
        for item in grammar where item.exerciseLanguage == language && seen.insert(item.topic).inserted {
            topics.append(item.topic)
        }
        return topics
    }

    /// Woerter der Satzbibliothek (Reserve fuer Ablenker bei wenigen Karten).
    func words(_ language: ExerciseLanguage, positions allowed: String? = nil) -> [String] {
        var out = Set<String>()
        for sentence in sentences {
            let toks = sentence.tokens(language), pos = sentence.positions(language)
            for (i, token) in toks.enumerated() where i < pos.count {
                if allowed == nil || allowed!.contains(pos[i]) { out.insert(token) }
            }
        }
        return Array(out).sorted()
    }
}
