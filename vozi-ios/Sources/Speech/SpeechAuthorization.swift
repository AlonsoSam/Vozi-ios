import Foundation
import Speech
import AVFoundation

/// Solicita consentimiento del adulto: reconocimiento de voz + micrófono.
/// (spec §7: consentimiento explícito del adulto en el onboarding.)
enum SpeechAuthorization {

    static func requestAll() async -> Bool {
        let speech = await requestSpeech()
        let mic = await requestMicrophone()
        return speech && mic
    }

    static func requestSpeech() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { cont in
            // iOS 17+: AVAudioApplication reemplaza a AVAudioSession.requestRecordPermission.
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
}
