import Foundation

/// Un ítem practicable dentro de una etapa: lo que el niño escucha y/o intenta decir.
///
/// `audioKey` es opcional a propósito: en Fase 1 el audio modelo se genera con
/// TTS del sistema (AVSpeechSynthesizer). Si más adelante se empaquetan clips de
/// voz humana curados, se rellena `audioKey` y la UI los usa sin cambios.
struct ContentItem: Identifiable, Hashable {
    let id = UUID()
    let text: String          // "ra", "rosa", "la rana salta"
    var audioKey: String? = nil

    /// Objetivo de coincidencia para el STT aproximado. Por defecto es `text`,
    /// pero permite separar lo que se narra de la palabra clave a evaluar.
    var matchTarget: String { text }
}

/// Contenido de una etapa (Escuchar/Sílabas/Palabras/Frases/Misión) para un fonema.
///
/// `usesMicrophone` y `threshold` son la "config de etapa": Escuchar no graba;
/// las demás sí. El umbral es configurable por fonema y etapa (spec §7).
///
/// NOTA: estos umbrales son provisionales (calibración inicial de Fase 0). La
/// lógica sensible de umbral definitivo migrará a Edge Functions en una fase
/// posterior; aquí viven solo como valores por defecto del cliente.
struct StageContent: Identifiable, Hashable {
    var id: LearningStage { stage }
    let stage: LearningStage
    let items: [ContentItem]
    let usesMicrophone: Bool
    let threshold: Double
}

/// Todo el contenido de un fonema: sus 5 etapas en orden pedagógico.
struct PhonemeContent: Identifiable {
    var id: String { phoneme.code }
    let phoneme: Phoneme
    let stages: [StageContent]

    func stage(_ stage: LearningStage) -> StageContent? {
        stages.first { $0.stage == stage }
    }
}

/// Catálogo de contenido del MVP (5 fonemas × 5 etapas), curado bajo enfoque
/// educativo (spec §10). Es estático y vive en el bundle: SwiftData guarda solo
/// estado y progreso, no contenido. Esto deja el catálogo fácil de mover a
/// Supabase (Storage/DB) más adelante sin tocar la persistencia de progreso.
enum ContentBank {

    // Umbrales por defecto por etapa. Las sílabas son cadenas cortas y más
    // sensibles a la distancia de edición, por eso un umbral algo más permisivo.
    private enum Threshold {
        static let silabas = 0.60
        static let palabras = 0.70
        static let frases = 0.65
        static let mision = 0.70
    }

    static let all: [PhonemeContent] = [
        // MARK: R
        PhonemeContent(phoneme: .r, stages: [
            StageContent(stage: .escuchar, items: items(["ra", "re", "ri", "ro", "ru", "rana"]),
                         usesMicrophone: false, threshold: 0),
            StageContent(stage: .silabas, items: items(["ra", "re", "ri", "ro", "ru"]),
                         usesMicrophone: true, threshold: Threshold.silabas),
            StageContent(stage: .palabras, items: items(["rana", "rosa", "pera", "loro"]),
                         usesMicrophone: true, threshold: Threshold.palabras),
            StageContent(stage: .frases, items: items(["la rana salta", "una rosa roja"]),
                         usesMicrophone: true, threshold: Threshold.frases),
            StageContent(stage: .mision, items: items(["el loro repite rosa"]),
                         usesMicrophone: true, threshold: Threshold.mision),
        ]),

        // MARK: RR
        PhonemeContent(phoneme: .rr, stages: [
            StageContent(stage: .escuchar, items: items(["rra", "rre", "rri", "rro", "rru", "perro"]),
                         usesMicrophone: false, threshold: 0),
            StageContent(stage: .silabas, items: items(["rra", "rre", "rri", "rro", "rru"]),
                         usesMicrophone: true, threshold: Threshold.silabas),
            StageContent(stage: .palabras, items: items(["perro", "carro", "torre"]),
                         usesMicrophone: true, threshold: Threshold.palabras),
            StageContent(stage: .frases, items: items(["el perro corre", "el carro rojo"]),
                         usesMicrophone: true, threshold: Threshold.frases),
            StageContent(stage: .mision, items: items(["el perro y el carro"]),
                         usesMicrophone: true, threshold: Threshold.mision),
        ]),

        // MARK: S
        PhonemeContent(phoneme: .s, stages: [
            StageContent(stage: .escuchar, items: items(["sa", "se", "si", "so", "su", "sapo"]),
                         usesMicrophone: false, threshold: 0),
            StageContent(stage: .silabas, items: items(["sa", "se", "si", "so", "su"]),
                         usesMicrophone: true, threshold: Threshold.silabas),
            StageContent(stage: .palabras, items: items(["sapo", "sol", "silla", "casa"]),
                         usesMicrophone: true, threshold: Threshold.palabras),
            StageContent(stage: .frases, items: items(["el sapo salta", "sale el sol"]),
                         usesMicrophone: true, threshold: Threshold.frases),
            StageContent(stage: .mision, items: items(["el sapo ve el sol"]),
                         usesMicrophone: true, threshold: Threshold.mision),
        ]),

        // MARK: L
        PhonemeContent(phoneme: .l, stages: [
            StageContent(stage: .escuchar, items: items(["la", "le", "li", "lo", "lu", "luna"]),
                         usesMicrophone: false, threshold: 0),
            StageContent(stage: .silabas, items: items(["la", "le", "li", "lo", "lu"]),
                         usesMicrophone: true, threshold: Threshold.silabas),
            StageContent(stage: .palabras, items: items(["luna", "lápiz", "pelota"]),
                         usesMicrophone: true, threshold: Threshold.palabras),
            StageContent(stage: .frases, items: items(["la luna brilla", "mi lápiz azul"]),
                         usesMicrophone: true, threshold: Threshold.frases),
            StageContent(stage: .mision, items: items(["la luna y la pelota"]),
                         usesMicrophone: true, threshold: Threshold.mision),
        ]),

        // MARK: TR
        PhonemeContent(phoneme: .tr, stages: [
            StageContent(stage: .escuchar, items: items(["tra", "tre", "tri", "tro", "tru", "tren"]),
                         usesMicrophone: false, threshold: 0),
            StageContent(stage: .silabas, items: items(["tra", "tre", "tri", "tro", "tru"]),
                         usesMicrophone: true, threshold: Threshold.silabas),
            StageContent(stage: .palabras, items: items(["tren", "trompo", "trigo"]),
                         usesMicrophone: true, threshold: Threshold.palabras),
            StageContent(stage: .frases, items: items(["el tren va", "un trompo gira"]),
                         usesMicrophone: true, threshold: Threshold.frases),
            StageContent(stage: .mision, items: items(["el tren con el trompo"]),
                         usesMicrophone: true, threshold: Threshold.mision),
        ]),
    ]

    static func content(for phoneme: Phoneme) -> PhonemeContent {
        // `all` cubre todos los casos del enum; el fallback nunca debería ocurrir.
        all.first { $0.phoneme == phoneme } ?? all[0]
    }

    static func stage(_ stage: LearningStage, for phoneme: Phoneme) -> StageContent? {
        content(for: phoneme).stage(stage)
    }

    // MARK: - Helpers

    private static func items(_ texts: [String]) -> [ContentItem] {
        texts.map { ContentItem(text: $0) }
    }
}
