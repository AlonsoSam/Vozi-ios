import Foundation
import AVFoundation

/// Narración del "audio modelo" con TTS del sistema (AVSpeechSynthesizer).
///
/// Decisión de Fase 1: el audio modelo se genera por TTS. Si más adelante se
/// empaquetan clips de voz humana curados, se reproducen desde `ContentItem.audioKey`
/// sin cambiar las vistas. Este servicio es independiente del STT de Fase 0.
@Observable
final class ModelVoiceService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private let localeID: String

    /// true mientras se está narrando (para resaltar el botón en la UI).
    private(set) var isSpeaking = false

    init(localeID: String = "es-MX") {
        self.localeID = localeID
        super.init()
        synth.delegate = self
    }

    /// Reproduce el audio modelo de un ítem: si hay un clip personalizado curado
    /// (`audioKey`), lo usa; si no, cae a TTS del sistema como respaldo (spec §10).
    func speak(item: ContentItem) {
        if let url = ModelAudioCatalog.url(forKey: item.audioKey), playClip(url) {
            return
        }
        speak(item.text)
    }

    func speak(_ text: String) {
        configureSessionForPlayback()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: localeID)
            ?? AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9  // algo más lento para niños
        utterance.pitchMultiplier = 1.05
        synth.speak(utterance)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        if player?.isPlaying == true { player?.stop() }
        player = nil
        isSpeaking = false
    }

    /// Reproduce un clip modelo empaquetado. Devuelve `false` si no se pudo cargar
    /// (entonces el llamador cae a TTS). Solo audio MODELO curado, nunca del niño.
    private func playClip(_ url: URL) -> Bool {
        configureSessionForPlayback()
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            player = p
            isSpeaking = true
            p.play()
            return true
        } catch {
            player = nil
            return false
        }
    }

    /// La etapa Escuchar no graba; solo reproduce. Categoría de reproducción.
    private func configureSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }

    // MARK: - AVSpeechSynthesizerDelegate (callbacks en main thread)

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    // MARK: - AVAudioPlayerDelegate (clip de audio modelo)

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isSpeaking = false
        self.player = nil
    }
}
