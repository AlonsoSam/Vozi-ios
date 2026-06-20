import Foundation
import SwiftData

/// Juicio humano del adulto sobre la pronunciación real del niño.
/// Es la "verdad de referencia" para calibrar el umbral del algoritmo.
enum HumanJudgment: String, CaseIterable, Identifiable {
    case correct    = "Correcto"
    case acceptable = "Aceptable"
    case incorrect  = "Incorrecto"
    var id: String { rawValue }
}

/// Un intento de prueba de Speech-to-Text persistido localmente (SwiftData).
///
/// Privacidad (spec §7): se guarda SOLO texto y métricas. Nunca audio crudo.
/// Los nombres de campo están pensados para mapear luego a una tabla
/// `speech_attempts` en Supabase (Fase 1+), sin conectarla todavía.
@Model
final class SpeechAttempt {
    var id: UUID
    var timestamp: Date
    var targetPhoneme: String
    var targetWord: String
    var stage: String
    var rawTranscription: String      // texto, nunca audio
    var similarityScore: Double       // 0...1
    var thresholdUsed: Double
    var algorithmPassed: Bool
    var humanJudgment: String
    var durationMs: Int
    var recognizerLocale: String      // ej. "es-PE"
    var onDevice: Bool                // true si el reconocimiento fue local
    var childAgeBand: String          // "4-5" / "6-7"

    init(
        targetPhoneme: String,
        targetWord: String,
        stage: String,
        rawTranscription: String,
        similarityScore: Double,
        thresholdUsed: Double,
        algorithmPassed: Bool,
        humanJudgment: String,
        durationMs: Int,
        recognizerLocale: String,
        onDevice: Bool,
        childAgeBand: String
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.targetPhoneme = targetPhoneme
        self.targetWord = targetWord
        self.stage = stage
        self.rawTranscription = rawTranscription
        self.similarityScore = similarityScore
        self.thresholdUsed = thresholdUsed
        self.algorithmPassed = algorithmPassed
        self.humanJudgment = humanJudgment
        self.durationMs = durationMs
        self.recognizerLocale = recognizerLocale
        self.onDevice = onDevice
        self.childAgeBand = childAgeBand
    }
}
