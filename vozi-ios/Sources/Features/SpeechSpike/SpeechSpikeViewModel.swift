import Foundation
import SwiftData

enum AgeBand: String, CaseIterable, Identifiable {
    case young = "4-5"
    case older = "6-7"
    var id: String { rawValue }
}

/// MVVM: la View no toca SFSpeechRecognizer; habla con este ViewModel,
/// que orquesta el servicio de voz y el matcher.
@MainActor
@Observable
final class SpeechSpikeViewModel {
    // Configuración (operada por el adulto)
    var selectedPhoneme = "R"
    var selectedPrompt: TestPrompt
    var selectedLocaleID: String
    var threshold: Double = 0.7
    var ageBand: AgeBand = .young

    // Estado en vivo
    var isRecording = false
    var liveTranscription = ""
    var lastResult: MatchResult?
    var lastError: String?
    var usedOnDevice = false
    var hasResult = false

    let availableLocales: [LocaleOption]

    private let speech = SpeechRecognitionService()
    private var startTime: Date?

    init() {
        let locales = SupportedLocales.available()
        self.availableLocales = locales
        self.selectedLocaleID = SupportedLocales.preferred(in: locales)
        self.selectedPrompt = PromptBank.prompts(for: "R").first!
    }

    var prompts: [TestPrompt] { PromptBank.prompts(for: selectedPhoneme) }

    func refreshPromptForPhoneme() {
        if let first = prompts.first { selectedPrompt = first }
    }

    func toggleRecording() {
        isRecording ? stop() : start()
    }

    private func start() {
        lastError = nil
        liveTranscription = ""
        lastResult = nil
        hasResult = false
        startTime = Date()
        do {
            try speech.start(
                localeID: selectedLocaleID,
                onTranscription: { [weak self] text in self?.liveTranscription = text },
                onError: { [weak self] err in self?.lastError = err.localizedDescription }
            )
            isRecording = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func stop() {
        speech.stop()
        isRecording = false
        usedOnDevice = speech.usedOnDevice
        lastResult = ApproximateMatcher.evaluate(
            target: selectedPrompt.word,
            transcription: liveTranscription,
            threshold: threshold
        )
        hasResult = true
    }

    func save(judgment: HumanJudgment, context: ModelContext) {
        guard let result = lastResult else { return }
        let duration = startTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        let attempt = SpeechAttempt(
            targetPhoneme: selectedPrompt.phoneme,
            targetWord: selectedPrompt.word,
            stage: selectedPrompt.stage.rawValue,
            rawTranscription: liveTranscription,
            similarityScore: result.score,
            thresholdUsed: threshold,
            algorithmPassed: result.passed,
            humanJudgment: judgment.rawValue,
            durationMs: duration,
            recognizerLocale: selectedLocaleID,
            onDevice: usedOnDevice,
            childAgeBand: ageBand.rawValue
        )
        context.insert(attempt)
        try? context.save()

        // Reset para el siguiente intento.
        liveTranscription = ""
        lastResult = nil
        hasResult = false
    }
}
