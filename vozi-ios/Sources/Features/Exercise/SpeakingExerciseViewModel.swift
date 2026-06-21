import Foundation
import SwiftData

/// Orquesta la práctica de Palabras con voz (flujo único del MVP).
///
/// Evaluación BASE on-device: `SpeechRecognitionService` (Apple, NO se toca) +
/// `PhonemeWordEvaluator` (regla por fonema/grupo sobre la palabra exacta
/// normalizada). El reconocimiento es en vivo; el STT base es coincidencia
/// aproximada, no juez final (la validación final es el juicio adulto).
///
/// El audio modelo se reproduce con `ModelVoiceService` (clip curado o TTS).
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
    var lastPhonemeMissed = false     // falló por no conservar el sonido del fonema
    var liveTranscription = ""
    var lastError: String?
    var lastResult: MatchResult?
    var showResult = false
    var finished = false

    /// Aciertos por palabra en ESTA sesión (gamificación, Fase 4). Una palabra
    /// cuenta como acertada si pasó al menos una vez; los reintentos no penalizan.
    /// Es independiente de la evaluación por palabra (solo registra su resultado).
    private(set) var itemPassed: [Bool]

    private var startTime: Date?
    private var usedOnDevice = false

    init(content: StageContent, phoneme: Phoneme, profile: ChildProfile?) {
        self.content = content
        self.phoneme = phoneme
        self.profile = profile
        self.localeID = SupportedLocales.preferred(in: SupportedLocales.available())
        self.itemPassed = Array(repeating: false, count: content.items.count)
    }

    var item: ContentItem { content.items[index] }
    var totalItems: Int { content.items.count }
    var isLastItem: Bool { index >= content.items.count - 1 }
    var passed: Bool { lastResult?.passed ?? false }

    // MARK: - Recompensa de la sesión (gamificación, Fase 4)

    /// Palabras distintas acertadas en la sesión.
    var passedCount: Int { itemPassed.filter { $0 }.count }

    /// Aciertos mínimos para ganar recompensa: 90% del total (10 palabras → 9).
    var requiredCorrect: Int { Int(ceil(Double(totalItems) * 0.9)) }

    /// ¿La sesión alcanza el 90% de aciertos para sumar puntos y completar?
    var rewardEarned: Bool { passedCount >= requiredCorrect }

    /// Reproduce el modelo / pista: clip personalizado si existe, TTS si no.
    /// No disponible mientras se graba.
    func playModel() {
        guard !isRecording else { return }
        voice.speak(item: item)
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
        lastPhonemeMissed = false
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

        // Palabras: regla por fonema/grupo sobre la palabra exacta, no solo similitud.
        let word = PhonemeWordEvaluator.evaluate(
            phoneme: phoneme,
            target: item.matchTarget,
            transcription: liveTranscription,
            threshold: content.threshold
        )
        let result = MatchResult(score: word.score, passed: word.passed)
        // Falló conservando poco el sonido objetivo → pista educativa específica.
        lastPhonemeMissed = !word.passed && !word.phonemeOk

        // Gamificación: marca el ítem como acertado si pasó (no se revierte con
        // reintentos posteriores). No altera la evaluación por palabra.
        if result.passed { itemPassed[index] = true }

        lastResult = result
        showResult = true

        // Audio modelo de feedback (Fase 5): frase aleatoria de aliento. Opcional:
        // si no hay clip, no reproduce nada. No afecta la evaluación.
        voice.playFeedback(result.passed ? .correct : .incorrect)

        saveAttempt(result: result, transcription: liveTranscription,
                    threshold: content.threshold, context: context)
    }

    // MARK: - Persistencia

    private func saveAttempt(result: MatchResult, transcription: String,
                             threshold: Double, context: ModelContext) {
        let duration = startTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        let attempt = SpeechAttempt(
            targetPhoneme: phoneme.code,
            targetWord: item.matchTarget,
            stage: content.stage.rawValue,
            rawTranscription: transcription,
            similarityScore: result.score,
            thresholdUsed: threshold,
            algorithmPassed: result.passed,
            humanJudgment: "",                 // el adulto valida en el panel
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
        lastPhonemeMissed = false
    }

    /// Avanza al siguiente ítem o marca el ejercicio como terminado.
    func advance() {
        voice.stop()
        if isLastItem {
            finished = true
            // Audio modelo de cierre (Fase 5): frase aleatoria de fin de sesión.
            // Opcional; si no hay clip, no reproduce nada.
            voice.playFeedback(.sessionComplete)
        } else {
            index += 1
            showResult = false
            lastResult = nil
            liveTranscription = ""
            lastPhonemeMissed = false
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
