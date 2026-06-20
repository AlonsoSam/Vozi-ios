import Foundation

/// Etapas pedagógicas (§9 del spec). En Fase 0 solo son etiquetas referenciales:
/// NO se implementa el flujo navegable de las 5 etapas todavía.
enum LearningStage: String, CaseIterable, Codable {
    case escuchar = "Escuchar"
    case silabas  = "Sílabas"
    case palabras = "Palabras"
    case frases   = "Frases"
    case mision   = "Misión"
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
