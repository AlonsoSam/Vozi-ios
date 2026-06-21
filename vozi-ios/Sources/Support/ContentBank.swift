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

    /// Clave estable del asset de imagen estática de apoyo (spec §10), opcional
    /// como `audioKey`. Se rellena en Palabras; si es `nil` o el asset no existe,
    /// la UI usa un placeholder (`WordImageCatalog`). Ej: "word_rana".
    var imageKey: String? = nil

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

    // Umbral por defecto para Palabras (evaluación principal del MVP). Es APOYO:
    // la aprobación además exige conservar el sonido del fonema (PhonemeWordEvaluator).
    private enum Threshold {
        static let palabras = 0.70
    }

    // Banco de ~10 palabras por fonema (Fase 2 reenfocada a palabras). Cada palabra
    // recibe su imageKey derivado por `words()`; si el asset no existe, la UI usa
    // placeholder. La etapa Escuchar reutiliza las mismas palabras (imagen + audio).
    private static let rWords  = ["rana", "rosa", "ratón", "reloj", "rueda", "rama", "regalo", "río", "ropa", "radio"]
    private static let rrWords = ["perro", "carro", "torre", "burro", "gorra", "jarra", "tierra", "barro", "parra", "cerro"]
    private static let sWords  = ["sapo", "sol", "silla", "sopa", "sandía", "saco", "semilla", "sombrero", "serpiente", "sirena"]
    private static let lWords  = ["luna", "lápiz", "loro", "leche", "lámpara", "libro", "limón", "llave", "lobo", "lata"]
    private static let trWords = ["tren", "trapo", "trono", "trigo", "trompo", "tres", "trozo", "trucha", "trenza", "trofeo"]
    private static let prWords = ["proa", "presa", "prisa", "prado", "prenda", "pradera", "prendedor", "prensa", "pronto", "promesa"]
    private static let plWords = ["plato", "pluma", "playa", "plaza", "pleno", "pliego", "plancha", "plano", "plaga", "plomo"]
    private static let brWords = ["brazo", "brisa", "brocha", "brasa", "bravo", "brillo", "broma", "cebra", "libro", "cabra"]
    private static let blWords = ["blanco", "blusa", "bloque", "blando", "cable", "tabla", "pueblo", "mueble", "ombligo", "establo"]

    static let all: [PhonemeContent] = [
        mvp(.r,  rWords),
        mvp(.rr, rrWords),
        mvp(.s,  sWords),
        mvp(.l,  lWords),
        mvp(.tr, trWords),
        mvp(.pr, prWords),
        mvp(.pl, plWords),
        mvp(.br, brWords),
        mvp(.bl, blWords),
    ]

    /// Construye el contenido MVP de un fonema: solo Palabras (evaluación principal
    /// con micrófono). Cada palabra trae imagen, texto, botón de escuchar modelo/TTS
    /// y botón de pronunciar.
    private static func mvp(_ phoneme: Phoneme, _ wordList: [String]) -> PhonemeContent {
        PhonemeContent(phoneme: phoneme, stages: [
            StageContent(stage: .palabras, items: words(wordList),
                         usesMicrophone: true, threshold: Threshold.palabras),
        ])
    }

    static func content(for phoneme: Phoneme) -> PhonemeContent {
        // `all` cubre todos los casos del enum; el fallback nunca debería ocurrir.
        all.first { $0.phoneme == phoneme } ?? all[0]
    }

    static func stage(_ stage: LearningStage, for phoneme: Phoneme) -> StageContent? {
        content(for: phoneme).stage(stage)
    }

    // MARK: - Helpers

    /// Asocia a cada palabra su clave de imagen estática
    /// derivada del texto (spec §10). El asset puede no existir aún: la UI usa
    /// placeholder vía `WordImageCatalog`.
    private static func words(_ texts: [String]) -> [ContentItem] {
        texts.map { ContentItem(text: $0, imageKey: WordImageCatalog.imageKey(for: $0)) }
    }
}
