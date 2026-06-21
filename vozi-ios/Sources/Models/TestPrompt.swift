import Foundation

/// Etapas pedagógicas (§9 del spec). En Fase 0 solo son etiquetas referenciales:
/// NO se implementa el flujo navegable de las 5 etapas todavía.
enum LearningStage: String, CaseIterable, Codable {
    case escuchar = "Escuchar"
    case silabas  = "Sílabas"
    case palabras = "Palabras"
    case frases   = "Frases"
    case mision   = "Misión"

    /// Flujo del MVP reenfocado (Fase 2): SOLO Palabras (evaluación principal con
    /// STT base on-device). El modelo de voz/TTS se escucha con el botón dentro de
    /// cada palabra, así que Escuchar deja de ser una etapa aparte. Sílabas/Frases/
    /// Misión se mantienen en el enum por compatibilidad con datos previos y con el
    /// spike de validación, pero quedan fuera del flujo.
    static let mvpFlow: [LearningStage] = [.palabras]
}

/// Palabra/objetivo de pronunciación para una prueba de STT.
struct TestPrompt: Identifiable, Hashable {
    let id: UUID
    let phoneme: String   // "R", "S", "L"
    let word: String
    let stage: LearningStage

    init(phoneme: String, word: String, stage: LearningStage) {
        self.id = UUID()
        self.phoneme = phoneme
        self.word = word
        self.stage = stage
    }
}
