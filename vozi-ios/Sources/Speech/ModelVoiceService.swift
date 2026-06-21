import Foundation
import AVFoundation

/// Narración del "audio modelo" con TTS del sistema (AVSpeechSynthesizer).
///
/// El audio modelo se genera por TTS. Si más adelante se empaquetan clips de voz
/// humana curados, se reproducen desde `ContentItem.audioKey` sin cambiar las
/// vistas. Este servicio es independiente del STT base.
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

    /// Reproduce el audio modelo de un ítem (botón Escuchar). Prioridad (spec §10,
    /// Fase 5): 1) `.mp3` personalizado de la palabra; 2) clip curado `.m4a` por
    /// `audioKey`; 3) TTS del sistema como respaldo. Nunca audio del niño.
    func speak(item: ContentItem) {
        if let url = ModelAudioCatalog.wordURL(for: item.text), playClip(url) {
            return
        }
        if let url = ModelAudioCatalog.url(forKey: item.audioKey), playClip(url) {
            return
        }
        speak(item.text)
    }

    /// Reproduce una frase de feedback aleatoria (acierto / fallo / fin de sesión)
    /// si existe el audio; si no, no hace nada (sin crashear ni hablar por TTS).
    /// Solo audio modelo curado, nunca del niño.
    func playFeedback(_ kind: ModelAudioCatalog.Feedback) {
        guard let url = ModelAudioCatalog.randomFeedbackURL(kind) else { return }
        _ = playClip(url)
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

    /// Categoría de reproducción para el audio modelo (no graba).
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
