import Foundation

/// Resultado de evaluación avanzada de pronunciación (Azure Pronunciation
/// Assessment u otro proveedor).
///
/// EDUCATIVO y referencial (spec §7): apoya la práctica y el seguimiento; nunca
/// es un diagnóstico clínico. Puntajes en escala 0...100 (HundredMark de Azure).
/// Solo guarda texto y métricas, nunca audio.
struct AdvancedEvaluation {
    let accuracyScore: Double
    let fluencyScore: Double
    let completenessScore: Double
    let pronScore: Double          // puntaje global del proveedor
    let provider: String           // "azure"
    let recognizedText: String     // texto reconocido (nunca audio)
    let evaluatedAt: Date
}

/// Errores posibles de la evaluación avanzada. Provocan fallback a Apple STT.
enum EvaluationError: Error, LocalizedError {
    case notConfigured
    case noConsent
    case network(String)
    case badResponse
    case noResult

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Evaluación avanzada no configurada."
        case .noConsent:     return "Falta consentimiento del adulto."
        case .network(let m): return "Error de red: \(m)"
        case .badResponse:   return "Respuesta inválida del servicio."
        case .noResult:      return "Sin resultado de evaluación."
        }
    }
}

/// Interfaz neutral de evaluación avanzada de pronunciación. Permite cambiar de
/// proveedor (Azure hoy; otro mañana) sin tocar la UI ni el flujo del ejercicio.
///
/// Contrato de privacidad: el clip recibido es CORTO y TEMPORAL; el llamador es
/// responsable de borrarlo tras evaluar. El evaluador no persiste audio.
protocol PronunciationEvaluator {
    var providerName: String { get }
    var isConfigured: Bool { get }

    func evaluate(clipURL: URL,
                  referenceText: String,
                  localeID: String) async throws -> AdvancedEvaluation
}
