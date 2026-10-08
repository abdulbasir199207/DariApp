//
//  CardEditorViewModel.swift
//  DariApp
//
//  Steuert das Anlegen und Bearbeiten einer Karte. Haelt einen editierbaren
//  Arbeitszustand, der erst beim Speichern in SwiftData uebernommen wird.
//  Enthaelt zudem die Duplikatpruefung vor dem Speichern.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class CardEditorViewModel {

    // MARK: Editierbarer Zustand

    var germanTerms: [String]
    var persianTerms: [String]
    var transliteration: String
    var tagNames: [String]
    var audioFileName: String?
    var isActive: Bool
    var isFavorite: Bool
    var exampleGerman: String
    var examplePersian: String

    /// Aufnahmen, die beim Speichern geloescht werden (ersetzt/entfernt) – nie vorher, damit
    /// „Abbrechen" keine bestehende Aufnahme zerstoert.
    private var obsoleteAudio: [String] = []
    /// In dieser Sitzung neu aufgenommen (werden bei „Abbrechen" verworfen).
    private var newAudio: [String] = []

    /// Falls beim Speichern moegliche Duplikate gefunden werden.
    var duplicateWarning: [Card] = []

    private let context: ModelContext
    private let existingCard: Card?

    var isEditing: Bool { existingCard != nil }

    // MARK: Init

    init(context: ModelContext, card: Card? = nil) {
        self.context = context
        self.existingCard = card
        self.germanTerms = card?.germanTranslations.isEmpty == false ? card!.germanTranslations : [""]
        self.persianTerms = card?.persianTranslations.isEmpty == false ? card!.persianTranslations : [""]
        self.transliteration = card?.transliteration ?? ""
        self.tagNames = card?.tags.map(\.name) ?? []
        self.audioFileName = card?.audioFileName
        self.isActive = card?.isActive ?? true
        self.isFavorite = card?.isFavorite ?? false
        self.exampleGerman = card?.exampleGerman ?? ""
        self.examplePersian = card?.examplePersian ?? ""
    }

    // MARK: Audio-Verwaltung

    func audioReplaced(old: String) { obsoleteAudio.append(old) }
    func audioRecorded(_ name: String) { newAudio.append(name) }

    /// „Abbrechen": neue Aufnahmen verwerfen, Bestehendes bleibt unberuehrt.
    func discardChanges() {
        let store = AudioFileStore()
        for name in newAudio where name != existingCard?.audioFileName { store.delete(name) }
        newAudio = []
        obsoleteAudio = []
    }

    // MARK: Validierung

    /// Bereinigte, nicht-leere deutsche Begriffe.
    var cleanedGerman: [String] {
        germanTerms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Bereinigte, nicht-leere persische Begriffe.
    var cleanedPersian: [String] {
        persianTerms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Speicherbar, wenn je Seite mindestens ein Begriff vorhanden ist.
    var canSave: Bool {
        !cleanedGerman.isEmpty && !cleanedPersian.isEmpty
    }

    // MARK: Duplikatpruefung

    /// Sucht bestehende Karten mit ueberschneidenden Begriffen (ausser der
    /// aktuell bearbeiteten). Ergebnis landet in `duplicateWarning`.
    /// - Returns: true, wenn moegliche Duplikate existieren.
    func checkForDuplicates() -> Bool {
        let germanSet = Set(cleanedGerman.map { $0.lowercased() })
        let persianSet = Set(cleanedPersian.map { AnswerChecker.normalize($0, isPersian: true) })

        let descriptor = FetchDescriptor<Card>()
        let all = (try? context.fetch(descriptor)) ?? []

        duplicateWarning = all.filter { card in
            if let existingCard, card.id == existingCard.id { return false }
            let cardGerman = Set(card.germanTranslations.map { $0.lowercased() })
            let cardPersian = Set(card.persianTranslations.map { AnswerChecker.normalize($0, isPersian: true) })
            return !germanSet.isDisjoint(with: cardGerman) || !persianSet.isDisjoint(with: cardPersian)
        }
        return !duplicateWarning.isEmpty
    }

    // MARK: Speichern

    /// Persistiert die Karte. Loest Tags auf (bestehende wiederverwenden,
    /// neue anlegen) und aktualisiert Zeitstempel.
    func save() {
        let card = existingCard ?? Card()
        card.germanTranslations = cleanedGerman
        card.persianTranslations = cleanedPersian
        card.transliteration = transliteration.trimmingCharacters(in: .whitespacesAndNewlines)
        card.tags = resolveTags()
        card.audioFileName = audioFileName
        card.isActive = isActive
        card.isFavorite = isFavorite
        card.exampleGerman = exampleGerman.trimmingCharacters(in: .whitespacesAndNewlines)
        card.examplePersian = examplePersian.trimmingCharacters(in: .whitespacesAndNewlines)
        card.updatedAt = Date()

        if existingCard == nil {
            context.insert(card)
        }
        if context.saveReporting() {
            let store = AudioFileStore()
            for name in obsoleteAudio where name != audioFileName { store.delete(name) }
            obsoleteAudio = []; newAudio = []
        }
    }

    /// Wandelt eingegebene Tag-Namen in `Tag`-Entities um; bestehende werden
    /// per Name wiederverwendet, unbekannte neu erzeugt.
    private func resolveTags() -> [Tag] {
        let names = Set(tagNames.map(Tag.normalize).filter { !$0.isEmpty })
        let descriptor = FetchDescriptor<Tag>()
        let existing = (try? context.fetch(descriptor)) ?? []
        var byName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })

        var result: [Tag] = []
        for name in names {
            if let tag = byName[name] {
                result.append(tag)
            } else {
                let tag = Tag(name: name)
                context.insert(tag)
                byName[name] = tag
                result.append(tag)
            }
        }
        return result
    }
}
