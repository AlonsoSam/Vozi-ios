import Foundation
import AVFoundation

/// Narración del "audio modelo" con TTS del sistema (AVSpeechSynthesizer).
///
/// Decisión de Fase 1: el audio modelo se genera por TTS. Si más adelante se
/// empaquetan clips de voz humana curados, se reproducen desde `ContentItem.audioKey`
/// sin cambiar las vistas. Este servicio es independiente del STT de Fase 0.
@Observable
final class ModelVoiceService: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private let localeID: String

    /// true mientras se está narrando (para resaltar el botón en la UI).
    private(set) var isSpeaking = false

    init(localeID: String = "es-MX") {
        self.localeID = localeID
        super.init()
        synth.delegate = self
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
}
