import Foundation
import Speech
import AVFoundation

enum SpeechError: LocalizedError {
    case localeUnavailable
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .localeUnavailable:     return "El idioma seleccionado no está disponible para reconocimiento."
        case .recognizerUnavailable: return "El reconocedor de voz no está disponible en este momento."
        }
    }
}

/// Wrapper sobre SFSpeechRecognizer + AVAudioEngine.
///
/// Política on-device (ajuste aprobado):
///  - Si el reconocedor SOPORTA on-device → se fuerza local: el audio NO sale del dispositivo.
///  - Si NO lo soporta → fallback al motor disponible de iOS (puede usar servidor).
/// En ambos casos VOZI no almacena ni sube audio crudo; la UI avisa cuando no fue on-device.
final class SpeechRecognitionService {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    /// true si el último inicio usó reconocimiento local.
    private(set) var usedOnDevice = false

    /// true mientras se detiene manualmente: la cancelación resultante es esperada.
    private var isStopping = false
    /// true si el reconocedor ya entregó al menos una transcripción no vacía.
    private var receivedTranscription = false

    func start(
        localeID: String,
        onTranscription: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) throws {
        stop()
        isStopping = false
        receivedTranscription = false

        let locale = Locale(identifier: localeID)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechError.localeUnavailable
        }
        guard recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true   // prioriza local
            usedOnDevice = true
        } else {
            request.requiresOnDeviceRecognition = false  // fallback motor disponible
            usedOnDevice = false
        }
        self.request = request

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { onTranscription(text) }
            }
            if let error {
                DispatchQueue.main.async { onError(error) }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
