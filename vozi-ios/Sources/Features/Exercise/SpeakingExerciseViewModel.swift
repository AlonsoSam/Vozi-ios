import Foundation
import SwiftData

/// Orquesta una etapa de práctica con voz (Sílabas/Palabras/Frases/Misión).
///
/// Dos modos de evaluación:
///  - BASE (Fase 0/1): `SpeechRecognitionService` (Apple on-device, NO se toca) +
///    `ApproximateMatcher`. Reconocimiento en vivo.
///  - AVANZADO (Fase 2): si Azure está configurado Y el adulto dio consentimiento,
///    graba un clip corto temporal y lo evalúa con `AzurePronunciationEvaluator`.
///    Si Azure falla, hace fallback a Apple sobre el mismo clip
///    (`AppleClipRecognizer`). El clip se borra siempre tras evaluar.
///
/// El audio modelo se reproduce con `ModelVoiceService` (clip o TTS).
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
    private let clipRecorder = AudioClipRecorder()
    private let azure = AzurePronunciationEvaluator()

    /// Umbrales educativos del modo avanzado (escala 0...100, configurables).
    /// Palabras/frases: criterio normal. Sílabas: práctica guiada, más permisivo.
    private let advancedWordPass = 60.0
    private let advancedSyllablePass = 40.0

    var index = 0
    var isRecording = false
    var isEvaluating = false          // esperando la evaluación avanzada
    var heardButNoScore = false       // avanzado: se reconoció voz pero sin puntaje útil
    var lastPhonemeMissed = false     // falló por no conservar el sonido del fonema
    var liveTranscription = ""
    var lastError: String?
    var lastResult: MatchResult?
    var showResult = false
    var finished = false

    private var startTime: Date?
    private var usedOnDevice = false
    private var advancedActive = false   // true si este intento usa el camino avanzado

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

    /// El modo avanzado se ofrece solo si Azure está configurado Y hay
    /// consentimiento del adulto. Si no, todo va por el modo base.
    private var advancedAvailable: Bool {
        AdvancedConsentStore.featureEnabled
            && azure.isConfigured
            && AdvancedConsentStore.isGranted
    }

    /// Reproduce el modelo / pista: clip personalizado si existe, TTS si no.
    /// No disponible mientras se graba.
    func playModel() {
        guard !isRecording else { return }
        voice.speak(item: item)
    }

    func micTapped(context: ModelContext) {
        if isRecording {
            if advancedActive {
                stopAndEvaluateAdvanced(context: context)
            } else {
                stopAndEvaluateBase(context: context)
            }
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
        heardButNoScore = false
        lastPhonemeMissed = false
        startTime = Date()
        advancedActive = advancedAvailable

        if advancedActive {
            // Modo avanzado: graba un clip corto temporal (sin transcripción en vivo).
            do {
                try clipRecorder.start()
                isRecording = true
            } catch {
                // Si no se puede grabar el clip, cae al modo base.
                advancedActive = false
                startBaseRecording()
            }
        } else {
            startBaseRecording()
        }
    }

    private func startBaseRecording() {
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

    // MARK: - Modo base (Apple en vivo)

    private func stopAndEvaluateBase(context: ModelContext) {
        speech.stop()
        isRecording = false
        usedOnDevice = speech.usedOnDevice

        // Palabras (evaluación principal del MVP): regla por fonema, no solo
        // similitud. Otras etapas (ej. datos antiguos) usan similitud simple.
        let result: MatchResult
        if content.stage == .palabras {
            let word = PhonemeWordEvaluator.evaluate(
                phoneme: phoneme,
                target: item.matchTarget,
                transcription: liveTranscription,
                threshold: content.threshold
            )
            result = MatchResult(score: word.score, passed: word.passed)
            // Falló conservando poco el sonido objetivo → pista educativa específica.
            lastPhonemeMissed = !word.passed && !word.phonemeOk
        } else {
            result = ApproximateMatcher.evaluate(
                target: item.matchTarget,
                transcription: liveTranscription,
                threshold: content.threshold
            )
            lastPhonemeMissed = false
        }

        lastResult = result
        showResult = true
        saveAttempt(result: result, transcription: liveTranscription,
                    threshold: content.threshold, mode: "base",
                    eval: nil, context: context)
    }

    // MARK: - Modo avanzado (Azure, con fallback a Apple)

    private func stopAndEvaluateAdvanced(context: ModelContext) {
        guard let clipURL = clipRecorder.stop() else {
            isRecording = false
            advancedActive = false
            return
        }
        isRecording = false
        isEvaluating = true
        usedOnDevice = false

        Task { await evaluateAdvanced(clipURL: clipURL, context: context) }
    }

    private func evaluateAdvanced(clipURL: URL, context: ModelContext) async {
        defer {
            clipRecorder.deleteClip()   // privacidad: borrar siempre el clip temporal
            advancedActive = false
        }
        let target = item.matchTarget
        do {
            let eval = try await azure.evaluate(
                clipURL: clipURL, referenceText: target, localeID: localeID
            )
            // La transcripción normalizada es solo APOYO/registro, no el juez.
            let textMatch = ApproximateMatcher.evaluate(
                target: target, transcription: eval.recognizedText,
                threshold: content.threshold
            )

            // ¿Azure devolvió puntaje útil? Si todo viene en 0, NO se aprueba por
            // transcripción: la evaluación avanzada se trata como "sin puntaje".
            let hasUsefulScore = eval.accuracyScore > 0 || eval.pronScore > 0
            // Sílabas: práctica guiada (umbral más permisivo). Palabras/frases: normal.
            let passScore = content.stage == .silabas ? advancedSyllablePass : advancedWordPass

            let passed: Bool
            if hasUsefulScore {
                passed = eval.accuracyScore >= passScore || eval.pronScore >= passScore
                heardButNoScore = false
            } else {
                // Sin puntaje útil: feedback amable, no se fuerza la aprobación.
                passed = false
                heardButNoScore = true
            }

            let result = MatchResult(score: textMatch.score, passed: passed)
            finishEvaluation(result: result, transcription: eval.recognizedText,
                             threshold: passScore / 100.0, mode: "advanced",
                             eval: eval, context: context)
        } catch {
            // Fallback: reconocimiento de Apple sobre el mismo clip.
            await fallbackToApple(clipURL: clipURL, target: target, context: context)
        }
    }

    private func fallbackToApple(clipURL: URL, target: String, context: ModelContext) async {
        heardButNoScore = false   // fallback usa modo base, no aplica este estado
        do {
            let text = try await AppleClipRecognizer.transcribe(
                clipURL: clipURL, localeID: localeID
            )
            usedOnDevice = true
            let result = ApproximateMatcher.evaluate(
                target: target, transcription: text, threshold: content.threshold
            )
            finishEvaluation(result: result, transcription: text,
                             threshold: content.threshold, mode: "base",
                             eval: nil, context: context)
        } catch {
            // Falla total: fracaso amable, permitir reintentar sin penalización.
            let result = MatchResult(score: 0, passed: false)
            lastError = "No se pudo evaluar. Intenta otra vez."
            finishEvaluation(result: result, transcription: "",
                             threshold: content.threshold, mode: "base",
                             eval: nil, context: context)
        }
    }

    private func finishEvaluation(result: MatchResult, transcription: String,
                                  threshold: Double, mode: String,
                                  eval: AdvancedEvaluation?, context: ModelContext) {
        isEvaluating = false
        lastResult = result
        showResult = true
        saveAttempt(result: result, transcription: transcription,
                    threshold: threshold, mode: mode, eval: eval, context: context)
    }

    // MARK: - Persistencia

    private func saveAttempt(result: MatchResult, transcription: String,
                             threshold: Double, mode: String,
                             eval: AdvancedEvaluation?, context: ModelContext) {
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
            childAgeBand: profile?.ageBand.rawValue ?? "",
            evaluationMode: mode,
            advancedProvider: eval?.provider,
            advancedAccuracy: eval?.accuracyScore,
            advancedFluency: eval?.fluencyScore,
            advancedCompleteness: eval?.completenessScore,
            evaluatedAt: eval?.evaluatedAt
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
        heardButNoScore = false
        lastPhonemeMissed = false
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
            heardButNoScore = false
            lastPhonemeMissed = false
        }
    }

    func stopAll() {
        voice.stop()
        if isRecording {
            if advancedActive {
                clipRecorder.stop()
                clipRecorder.deleteClip()
            } else {
                speech.stop()
            }
            isRecording = false
        }
    }
}
