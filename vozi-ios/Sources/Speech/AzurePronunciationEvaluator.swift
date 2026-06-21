import Foundation
import os

/// Evaluación avanzada real vía **Azure Speech REST + Pronunciation Assessment**.
///
/// Sin SDK externo: solo `URLSession`. Envía un clip WAV corto y la configuración
/// de evaluación en la cabecera `Pronunciation-Assessment` (JSON base64).
///
/// Privacidad (spec §6/§7): se envía solo el clip corto necesario; el llamador lo
/// borra después. La key se lee de `AzureSecrets` y nunca se imprime. Resultado
/// EDUCATIVO/referencial, nunca diagnóstico clínico.
struct AzurePronunciationEvaluator: PronunciationEvaluator {

    let providerName = "azure"
    var isConfigured: Bool { AzureSecrets.isConfigured }

    /// Log seguro: solo estructura, status y puntajes. NUNCA key, audio ni texto.
    private let log = Logger(subsystem: "com.alonsosam.voziios", category: "AzurePA")

    /// Locale para la evaluación (es-MX, según calibración de sílabas cortas).
    private let language = "es-MX"

    func evaluate(clipURL: URL,
                  referenceText: String,
                  localeID: String) async throws -> AdvancedEvaluation {
        guard isConfigured else { throw EvaluationError.notConfigured }

        let region = AzureSecrets.region

        // Host REST de short audio para STT (distinto del endpoint de recurso).
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "\(region).stt.speech.microsoft.com"
        comps.path = "/speech/recognition/conversation/cognitiveservices/v1"
        comps.queryItems = [
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "detailed"),
        ]
        guard let url = comps.url else { throw EvaluationError.badResponse }

        // Configuración de Pronunciation Assessment (JSON → base64 sin saltos de
        // línea para la cabecera). referenceText es el target EXACTO (con tildes).
        let paConfig: [String: Any] = [
            "ReferenceText": referenceText,
            "GradingSystem": "HundredMark",
            "Granularity": "Phoneme",
            "Dimension": "Comprehensive",
            "EnableMiscue": false,
        ]
        let paData = try JSONSerialization.data(withJSONObject: paConfig,
                                                options: [.sortedKeys])
        let paHeader = paData.base64EncodedString(options: [])

        let audio = try Data(contentsOf: clipURL)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(AzureSecrets.key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        req.setValue("audio/wav; codecs=audio/pcm; samplerate=16000",
                     forHTTPHeaderField: "Content-Type")
        req.setValue(paHeader, forHTTPHeaderField: "Pronunciation-Assessment")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = audio
        req.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw EvaluationError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw EvaluationError.badResponse
        }
        log.debug("HTTP status=\(http.statusCode, privacy: .public)")
        guard (200..<300).contains(http.statusCode) else {
            // No se incluye el cuerpo en el error para no arrastrar datos sensibles.
            throw EvaluationError.network("HTTP \(http.statusCode)")
        }
        return try parse(data)
    }

    // MARK: - Privados

    private func parse(_ data: Data) throws -> AdvancedEvaluation {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EvaluationError.badResponse
        }
        let status = (root["RecognitionStatus"] as? String) ?? "?"
        // Log seguro: solo NOMBRES de campos del JSON (no valores), para ver si
        // la cabecera de assessment fue aceptada. Nunca key, audio ni texto.
        log.debug("rootKeys=\(root.keys.sorted().joined(separator: ","), privacy: .public)")
        guard let best = (root["NBest"] as? [[String: Any]])?.first else {
            log.debug("status=\(status, privacy: .public) NBest=empty")
            throw EvaluationError.noResult
        }
        log.debug("bestKeys=\(best.keys.sorted().joined(separator: ","), privacy: .public)")
        let pa = best["PronunciationAssessment"] as? [String: Any] ?? [:]
        func score(_ k: String) -> Double { (pa[k] as? NSNumber)?.doubleValue ?? 0 }

        let recognized = (best["Display"] as? String)
            ?? (best["Lexical"] as? String)
            ?? ""

        // Log seguro: estructura + puntajes (no son sensibles); nunca el texto.
        log.debug("""
        status=\(status, privacy: .public) hasPA=\(!pa.isEmpty, privacy: .public) \
        acc=\(score("AccuracyScore"), privacy: .public) \
        flu=\(score("FluencyScore"), privacy: .public) \
        comp=\(score("CompletenessScore"), privacy: .public) \
        pron=\(score("PronScore"), privacy: .public)
        """)

        return AdvancedEvaluation(
            accuracyScore: score("AccuracyScore"),
            fluencyScore: score("FluencyScore"),
            completenessScore: score("CompletenessScore"),
            pronScore: score("PronScore"),
            provider: providerName,
            recognizedText: recognized,
            evaluatedAt: Date()
        )
    }
}
