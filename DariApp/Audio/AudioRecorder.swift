//
//  AudioRecorder.swift
//  DariApp
//
//  Kapselt Aufnahme und Wiedergabe von Sprachaufnahmen (m4a) via AVFoundation.
//  Beobachtbar (@Observable), sodass Views Aufnahme-/Abspielstatus direkt
//  binden koennen. Laeuft auf dem MainActor, da UI-Status verwaltet wird.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class AudioRecorder: NSObject {

    enum State: Equatable {
        case idle
        case recording
        case playing
    }

    private(set) var state: State = .idle
    private(set) var permissionDenied = false

    private let store = AudioFileStore()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    // MARK: - Berechtigung

    /// Fragt bei Bedarf die Mikrofonberechtigung an.
    func requestPermissionIfNeeded() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionDenied = !granted
        return granted
    }

    // MARK: - Aufnahme

    /// Startet eine neue Aufnahme und gibt den erzeugten Dateinamen zurueck.
    /// - Returns: Dateiname bei Erfolg, sonst `nil`.
    @discardableResult
    func startRecording() async -> String? {
        guard await requestPermissionIfNeeded() else { return nil }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return nil
        }

        let fileName = store.newFileName()
        let url = store.url(for: fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            guard recorder.record() else { return nil }
            self.recorder = recorder
            state = .recording
            return fileName
        } catch {
            return nil
        }
    }

    /// Beendet die laufende Aufnahme.
    func stopRecording() {
        recorder?.stop()
        recorder = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Wiedergabe

    /// Spielt eine gespeicherte Aufnahme ab.
    func play(fileName: String) {
        guard store.exists(fileName) else { return }
        let url = store.url(for: fileName)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            state = .playing
        } catch {
            state = .idle
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        state = .idle
    }

    // MARK: - Dateiverwaltung

    func deleteRecording(fileName: String) {
        store.delete(fileName)
    }

    func exists(fileName: String) -> Bool {
        store.exists(fileName)
    }
}

// MARK: - AVAudioRecorderDelegate / AVAudioPlayerDelegate

extension AudioRecorder: AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.state = .idle }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.state = .idle }
    }
}
