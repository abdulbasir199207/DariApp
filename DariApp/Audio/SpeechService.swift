//
//  SpeechService.swift
//  DariApp
//
//  Sprachausgabe (Text-to-Speech) fuer Hoerverstehen und Aussprache.
//  Es wird nur das genutzt, was das Geraet wirklich kann: Gibt es keine
//  persische Stimme, blendet die Oberflaeche die entsprechenden Aufgaben aus
//  bzw. nutzt die eigenen Aufnahmen der Karten.
//
//  Die Stimmenliste des Systems zu laden ist langsam (kann Sekunden dauern).
//  Deshalb passiert das einmal im Hintergrund (`prepare()`); die Oberflaeche
//  fragt nur noch zwischengespeicherte Werte ab.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class SpeechService {

    static let shared = SpeechService()

    /// Kennungen der gefundenen Stimmen (nil = keine vorhanden bzw. noch nicht geladen).
    private(set) var persianVoiceID: String?
    private(set) var germanVoiceID: String?
    private(set) var isReady = false

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var started = false

    /// Sucht die Stimmen einmalig im Hintergrund.
    func prepare() {
        guard !started else { return }
        started = true
        Task.detached(priority: .utility) { [weak self] in
            let voices = AVSpeechSynthesisVoice.speechVoices()
            let persian = voices.first { $0.language.hasPrefix("fa") || $0.language.hasPrefix("prs") }?.identifier
            let german = voices.first { $0.language.hasPrefix("de") }?.identifier
            await MainActor.run {
                self?.persianVoiceID = persian
                self?.germanVoiceID = german
                self?.isReady = true
            }
        }
    }

    func canSpeak(_ language: ExerciseLanguage) -> Bool {
        switch language {
        case .persian: return persianVoiceID != nil
        case .german: return germanVoiceID != nil
        }
    }

    func speak(_ text: String, language: ExerciseLanguage) {
        let id = language == .persian ? persianVoiceID : germanVoiceID
        guard !text.isEmpty, let id, let voice = AVSpeechSynthesisVoice(identifier: id) else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
