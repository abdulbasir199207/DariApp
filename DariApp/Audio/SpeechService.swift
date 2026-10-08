//
//  SpeechService.swift
//  DariApp
//
//  Sprachausgabe (Text-to-Speech) fuer Hoerverstehen und Aussprache.
//  Es wird nur das genutzt, was das Geraet wirklich kann: Gibt es keine
//  persische Stimme, blendet die Oberflaeche die entsprechenden Aufgaben aus
//  bzw. nutzt die eigenen Aufnahmen der Karten.
//

import Foundation
import AVFoundation

@MainActor
final class SpeechService {

    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private func voice(for language: ExerciseLanguage) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices().first { voice in
            switch language {
            case .persian: return voice.language.hasPrefix("fa") || voice.language.hasPrefix("prs")
            case .german: return voice.language.hasPrefix("de")
            }
        }
    }

    func canSpeak(_ language: ExerciseLanguage) -> Bool { voice(for: language) != nil }

    func speak(_ text: String, language: ExerciseLanguage) {
        guard !text.isEmpty, let voice = voice(for: language) else { return }
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
