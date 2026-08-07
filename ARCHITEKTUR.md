# DariApp – Architektur

Native iPhone-App (iOS 26+, Swift 6, SwiftUI, SwiftData) zum Offline-Lernen
von Persisch (Dari/Farsi). Einzelnutzer, kein Netzwerk, keine Cloud.

## Grundprinzipien

- **MVVM**: Views sind schlank und deklarativ; Logik liegt in ViewModels
  (`@Observable`) bzw. in zustandslosen Engine-Typen.
- **SwiftData** als lokale Persistenz (`Card`, `Tag`, `ReviewLog`).
- **Observation-Framework** statt `ObservableObject`/Combine.
- **Dependency Injection** über `@Environment` (`AppSettings`) und
  Konstruktor-Injektion (ModelContext, FSRS in ViewModels/Engines).
- **Testbarkeit**: Kernlogik (FSRS, AnswerChecker, Scheduler, Statistik) ist
  rein funktional und ohne UI/SwiftData prüfbar.

## Ordnerstruktur (`DariApp/`)

| Ordner | Inhalt |
|---|---|
| `App/` | Einstiegspunkt, RootView (TabBar), ModelContainer-Factory |
| `Models/` | SwiftData-Modelle + zentrale Enums |
| `ViewModels/` | Editor-, Lern-Session-, Statistik-Logik |
| `Views/` | Bildschirme je Tab (`Learn`, `Cards`, `Statistics`, `Settings`) |
| `Components/` | Wiederverwendbare UI-Bausteine (Karten, Buttons, Chips, Layout) |
| `DesignSystem/` | Farb-, Typo- und Layout-Tokens |
| `LearningEngine/` | FSRS-Algorithmus, Parameter, Review-Scheduler |
| `Audio/` | Aufnahme/Wiedergabe (AVFoundation) + Dateiablage |
| `Extensions/` | AnswerChecker (Normalisierung, Levenshtein) |
| `Utilities/` | AppSettings, PreviewData |

## Datenmodell

- `Card`: mehrere deutsche/persische Übersetzungen (`[String]`), Lautschrift,
  Tags (Many-to-Many), Audio-Dateiname, Favorit/Aktiv, Zeitstempel und
  FSRS-Lernfelder (Stabilität, Schwierigkeit, Termine, Zähler, Zustand).
- `Tag`: eindeutiger Name, Gegenrichtung der Beziehung.
- `ReviewLog`: eine Zeile je Wiederholung (Bewertung, Zeit, Modus) für
  effiziente Statistiken.

## Lernalgorithmus (FSRS 4.5)

`LearningEngine/FSRS.swift` implementiert den Free Spaced Repetition Scheduler
über Stabilität (S) und Schwierigkeit (D). Antworten werden aus der
Korrektheit (perfekt / Tippfehler / falsch) und der Antwortzeit in eine der
vier FSRS-Bewertungen übersetzt. `ReviewScheduler` sorgt für Durchmischung,
Tag-Interleaving und häufigere Wiederholung schwieriger Karten.

## Status der Phasen

- [x] Phase 1 – Projektarchitektur
- [x] Phase 2 – SwiftData-Datenmodell
- [x] Phase 3 – Navigation (TabBar + NavigationStack)
- [x] Phase 4 – Designsystem
- [x] Phase 5 – Kartenverwaltung (Liste, Suche, Editor, Duplikatwarnung)
- [x] Phase 6 – Audioaufnahme (AVFoundation, m4a)
- [x] Phase 7 – Lernalgorithmus (FSRS + Scheduler)
- [x] Phase 8 – Lernmodi (Umdrehen, Multiple Choice, Schreiben)
- [x] Phase 9 – Statistik (Swift Charts)
- [x] Phase 10 – Einstellungen
- [x] Phase 11 – Tests (Unit + UI, erste Abdeckung)
- [x] Phase 12 – Feinschliff (Asset-Catalog, Haptik, globale Animationssteuerung, Robustheit)

## Build

Nur auf macOS mit **Xcode 26**:

```bash
open DariApp.xcodeproj
```

Schema „DariApp" wählen, Ziel iPhone 14 Pro Max (iOS 26) – ausführen.
Das Projekt nutzt file-system-synchronisierte Gruppen: neue Dateien im Ordner
`DariApp/` werden automatisch ins Target aufgenommen.
