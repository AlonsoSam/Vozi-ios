import Foundation

/// Generador de CSV de intentos para análisis fuera de la app (calibración de
/// umbrales y seguimiento). Export local; sin Supabase ni reportes PDF (fases
/// posteriores). Solo texto y métricas, nunca audio.
enum AttemptCSV {
    static func make(_ attempts: [SpeechAttempt]) -> String {
        let header = "timestamp,phoneme,word,stage,transcription,similarity,threshold,algorithmPassed,humanJudgment,durationMs,locale,onDevice,ageBand"
        let df = ISO8601DateFormatter()
        let rows = attempts.map { a -> String in
            [
                df.string(from: a.timestamp),
                a.targetPhoneme,
                a.targetWord,
                a.stage,
                a.rawTranscription.replacingOccurrences(of: ",", with: " "),
                String(format: "%.3f", a.similarityScore),
                String(format: "%.2f", a.thresholdUsed),
                "\(a.algorithmPassed)",
                a.humanJudgment,
                "\(a.durationMs)",
                a.recognizerLocale,
                "\(a.onDevice)",
                a.childAgeBand
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
