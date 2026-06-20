import Foundation
import SwiftData

/// Orquesta una etapa de práctica con voz (Sílabas/Palabras/Frases/Misión).
///
/// Reutiliza tal cual lo validado en Fase 0:
///  - `SpeechRecognitionService` (STT on-device) — NO se modifica.
///  - `ApproximateMatcher` (coincidencia aproximada de palabra).
/// Y añade `ModelVoiceService` (TTS) para la pista/modelo.
///
/// Privacidad: solo se guarda texto y métricas en `SpeechAttempt`. Nunca audio.
@MainActor
@Observable
final class SpeakingExerciseViewModel {
    let content: StageContent
    let phoneme: Phoneme
    let profile: ChildProfile?
    let localeID: String

    private let speech = SpeechRecognitionService()
    private let voice = ModelVoiceService()

    var index = 0
    var isRecording = false
    var liveTranscription = ""
    var lastError: String?
    var lastResult: MatchResult?
    var showResult = false
    var finished = false

    private var startTime: Date?
    private var usedOnDevice = false

    init(content: StageContent, phoneme: Phoneme, profile: ChildProfile?) {
        self.content = content
        self.phoneme = phoneme
        self.profile = profile
        self.localeID = SupportedLocales.preferred(in: SupportedLocales.available())
    }

    var item: ContentItem { content.items[index] }
    var totalItems: Int { content.items.count }
    var isLastItem: Bool { index >= content.items.count - 1 }
    var passed: Bool { lastResult?.passed ?? false }

    /// Reproduce el modelo / pista (TTS). No disponible mientras se graba.
    func playModel() {
        guard !isRecording else { return }
        voice.speak(item.text)
    }

    func micTapped(context: ModelContext) {
        if isRecording {
            stopAndEvaluate(context: context)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        voice.stop()
        lastError = nil
        liveTranscription = ""
        lastResult = nil
        showResult = false
        startTime = Date()
        do {
            try speech.start(
                localeID: localeID,
                onTranscription: { [weak self] text in self?.liveTranscription = text },
                onError: { [weak self] err in self?.lastError = err.localizedDescription }
            )
            isRecording = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func stopAndEvaluate(context: ModelContext) {
        speech.stop()
        isRecording = false
        usedOnDevice = speech.usedOnDevice
        let result = ApproximateMatcher.evaluate(
            target: item.matchTarget,
            transcription: liveTranscription,
            threshold: content.threshold
        )
        lastResult = result
        showResult = true
        saveAttempt(result: result, context: context)
    }

    private func saveAttempt(result: MatchResult, context: ModelContext) {
        let duration = startTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        let attempt = SpeechAttempt(
            targetPhoneme: phoneme.code,
            targetWord: item.matchTarget,
            stage: content.stage.rawValue,
            rawTranscription: liveTranscription,
            similarityScore: result.score,
            thresholdUsed: content.threshold,
            algorithmPassed: result.passed,
            humanJudgment: "",                 // pendiente: el adulto valida en el panel
            durationMs: duration,
            recognizerLocale: localeID,
            onDevice: usedOnDevice,
            childAgeBand: profile?.ageBand.rawValue ?? ""
        )
        attempt.child = profile
        context.insert(attempt)
        try? context.save()
    }

    /// Fracaso amable: reintentar el mismo ítem sin penalización (spec §11).
    func retry() {
        showResult = false
        lastResult = nil
        liveTranscription = ""
    }

    /// Avanza al siguiente ítem o marca el ejercicio como terminado.
    func advance() {
        voice.stop()
        if isLastItem {
            finished = true
        } else {
            index += 1
            showResult = false
            lastResult = nil
            liveTranscription = ""
        }
    }

    func stopAll() {
        voice.stop()
        if isRecording {
            speech.stop()
            isRecording = false
        }
    }
}
