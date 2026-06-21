import Foundation
import Speech

/// Reconocimiento de Apple sobre un clip de ARCHIVO. Es el fallback cuando la
/// evaluación avanzada (Azure) no está disponible o falla.
///
/// NO toca `SpeechRecognitionService.swift` (reconocimiento en vivo de Fase 0):
/// usa una petición de archivo (`SFSpeechURLRecognitionRequest`) independiente y
/// reutiliza `ApproximateMatcher` en el llamador.
///
/// Privacidad: opera sobre el clip temporal que el llamador borra luego; devuelve
/// solo texto, nunca audio.
enum AppleClipRecognizer {

    static func transcribe(clipURL: URL, localeID: String) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)),
              recognizer.isAvailable else {
            throw EvaluationError.notConfigured
        }
        let request = SFSpeechURLRecognitionRequest(url: clipURL)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        return try await withCheckedThrowingContinuation { cont in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true
                    cont.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    finished = true
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
