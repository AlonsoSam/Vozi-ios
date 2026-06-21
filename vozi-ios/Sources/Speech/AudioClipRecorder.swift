import Foundation
import AVFoundation

/// Graba un clip de audio CORTO y TEMPORAL para la evaluación avanzada (spec §7).
///
/// Formato WAV PCM 16 kHz mono 16-bit, requerido por la REST de Azure. El clip
/// vive en el directorio temporal y DEBE borrarse tras evaluar (`deleteClip()`).
///
/// Privacidad: nunca se persiste ni se reutiliza. No se guarda audio crudo del
/// niño; el clip existe solo el tiempo necesario para la evaluación.
///
/// Independiente de `SpeechRecognitionService` (no se toca): es un grabador
/// aparte para producir el archivo que consume el evaluador avanzado.
final class AudioClipRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var clipURL: URL?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vozi_clip_\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.record()
        recorder = r
        clipURL = url
    }

    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        return clipURL
    }

    /// Borra el clip temporal. Llamar SIEMPRE tras evaluar (privacidad).
    func deleteClip() {
        if let url = clipURL { try? FileManager.default.removeItem(at: url) }
        clipURL = nil
    }
}
