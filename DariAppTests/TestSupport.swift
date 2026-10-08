//
//  TestSupport.swift
//  DariAppTests
//
//  Gemeinsame Hilfen: In-Memory-Container, der waehrend des Tests am Leben bleibt
//  (ein frei gewordener Container laesst den Kontext abstuerzen), und frische
//  Einstellungen ohne Seiteneffekte auf die echten UserDefaults.
//

import Foundation
import SwiftData
@testable import DariApp

@MainActor
final class TestEnv {

    let container: ModelContainer
    let settings: AppSettings

    var context: ModelContext { container.mainContext }

    init() {
        container = ModelContainerFactory.makeInMemory()
        let defaults = UserDefaults(suiteName: "zara.tests.\(UUID().uuidString)")!
        settings = AppSettings(defaults: defaults)
    }

    @discardableResult
    func addCard(_ german: [String], _ persian: [String], tags: [String] = [], translit: String = "") -> Card {
        var tagObjects: [Tag] = []
        for name in tags {
            let existing = (try? context.fetch(FetchDescriptor<Tag>()))?.first { $0.name == name }
            if let existing { tagObjects.append(existing) } else {
                let tag = Tag(name: name)
                context.insert(tag)
                tagObjects.append(tag)
            }
        }
        let card = Card(germanTranslations: german, persianTranslations: persian, transliteration: translit, tags: tagObjects)
        context.insert(card)
        return card
    }

    /// Zehn eindeutige Beispielkarten.
    @discardableResult
    func addSampleCards(_ n: Int = 10) -> [Card] {
        let persian = ["خانه", "مادر", "پدر", "آب", "رفتن", "خوردن", "نان", "دوست", "کتاب", "میز", "در", "پنجره"]
        let german = ["Haus", "Mutter", "Vater", "Wasser", "gehen", "essen", "Brot", "Freund", "Buch", "Tisch", "Tür", "Fenster"]
        return (0..<min(n, persian.count)).map { i in
            addCard([german[i]], [persian[i]], tags: [i % 2 == 0 ? "Alltag" : "Familie"], translit: "tr\(i)")
        }
    }

    func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }
}
