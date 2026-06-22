import Foundation
import SwiftData

/// Etapa pedagógica del MVP. El flujo actual es directo a **Palabras** (única
/// etapa): el niño ve la imagen y la palabra, escucha el modelo/TTS y la
/// pronuncia para la evaluación con STT base on-device. Las etapas antiguas
/// (Escuchar/Sílabas/Frases/Misión) se retiraron del MVP.
///
/// Se mantiene como enum (no como literal) porque `StageProgress` persiste su
/// `rawValue` y `ContentBank` indexa el contenido por etapa.
enum LearningStage: String, CaseIterable, Codable {
    case palabras = "Palabras"

    /// Flujo del MVP: solo Palabras.
    static let mvpFlow: [LearningStage] = [.palabras]
}

/// Subperfil por edad (spec §11): guía la experiencia (4–5 más audio/menos
/// lectura; 6–7 mayor autonomía). Se persiste como `rawValue` en el perfil.
enum AgeBand: String, CaseIterable, Identifiable {
    case young = "4-5"
    case older = "6-7"
    var id: String { rawValue }
}

/// Estado de avance de un fonema o etapa para un perfil de niño.
/// Se persiste como `rawValue` (String) para mapear directo a Supabase (Fase 1+),
/// sin conectarlo aún.
enum ProgressStatus: String, Codable, CaseIterable {
    case locked    = "locked"      // aún no disponible (candado)
    case available = "available"   // se puede practicar
    case completed = "completed"   // etapa/fonema terminado
}

/// Perfil de un niño administrado por el adulto (spec §5).
/// El niño no inicia sesión: el progreso se asocia a este perfil.
///
/// Privacidad: guarda solo datos mínimos del perfil. Nada de audio.
@Model
final class ChildProfile {
    var id: UUID
    var name: String
    var ageBandRaw: String        // "4-5" / "6-7" (ver `AgeBand`)
    var avatarKey: String         // placeholder; ilustración real en Fase 4
    var createdAt: Date

    /// Puntos acumulados de gamificación (Fase 4). +10 por lista de fonema/grupo
    /// terminada. Solo recompensa visual; no afecta la evaluación. Default a nivel
    /// de propiedad para migración ligera de SwiftData sobre stores previos.
    var points: Int = 0

    // MARK: - Sincronización (Fase 7.3 · sin sync todavía)
    /// Metadatos mínimos para el sync futuro con Supabase. Por ahora solo existen y
    /// se mantienen localmente; NO hay push/pull. Defaults a nivel de propiedad para
    /// migración ligera: filas existentes quedan `isDirty = true` (nada sincronizado
    /// aún) con `updatedAt` antiguo, listas para el primer push cuando llegue el sync.
    var updatedAt: Date = Date.distantPast
    var isDirty: Bool = true
    /// Borrado lógico (tombstone) para propagar la baja al sincronizar. Espeja
    /// `children.deleted_at` del backend. nil = activo. Aún NO se usa: el borrado de
    /// perfil sigue siendo físico (ver nota en ProfilesView); la conversión a
    /// soft-delete se hará en la fase de sync.
    var deletedAt: Date?

    /// Progreso por fonema. Cascade: borrar el perfil borra su progreso.
    @Relationship(deleteRule: .cascade, inverse: \PhonemeProgress.child)
    var phonemeProgress: [PhonemeProgress] = []

    /// Intentos de voz de este perfil. Nullify: borrar el perfil no borra el
    /// histórico de intentos (queda desligado), útil para análisis/CSV.
    @Relationship(deleteRule: .nullify, inverse: \SpeechAttempt.child)
    var attempts: [SpeechAttempt] = []

    init(name: String, ageBand: AgeBand, avatarKey: String = "default") {
        self.id = UUID()
        self.name = name
        self.ageBandRaw = ageBand.rawValue
        self.avatarKey = avatarKey
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Marca el perfil como cambiado para el sync futuro (sella `updatedAt`).
    func markDirty() {
        isDirty = true
        updatedAt = Date()
    }

    var ageBand: AgeBand { AgeBand(rawValue: ageBandRaw) ?? .young }

    /// Veces que se terminó la lista de palabras de un fonema/grupo (gamificación).
    /// Eje independiente del `status` de aprendizaje; alimenta el desbloqueo de skins.
    func completionCount(forCode code: String) -> Int {
        phonemeProgress.first { $0.phonemeCode == code }?.completionCount ?? 0
    }
}

/// Avance de un fonema concreto para un perfil.
@Model
final class PhonemeProgress {
    var id: UUID
    var phonemeCode: String       // "R", "RR", "S", "L", "TR"
    var statusRaw: String         // ver `ProgressStatus`

    /// Veces que el niño terminó la lista de palabras de este fonema/grupo
    /// (Fase 4). Eje de gamificación, independiente de `status`. Alimenta el
    /// desbloqueo de skins. Default a nivel de propiedad para migración ligera.
    var completionCount: Int = 0

    // MARK: - Sincronización (Fase 7.3 · sin sync todavía)
    var updatedAt: Date = Date.distantPast
    var isDirty: Bool = true
    var deletedAt: Date?

    var child: ChildProfile?

    /// Avance de las etapas de este fonema (MVP: solo Palabras). Cascade desde el fonema.
    @Relationship(deleteRule: .cascade, inverse: \StageProgress.phonemeProgress)
    var stages: [StageProgress] = []

    init(phonemeCode: String, status: ProgressStatus) {
        self.id = UUID()
        self.phonemeCode = phonemeCode
        self.statusRaw = status.rawValue
        self.updatedAt = Date()
    }

    /// Marca este avance como cambiado para el sync futuro (sella `updatedAt`).
    func markDirty() {
        isDirty = true
        updatedAt = Date()
    }

    var phoneme: Phoneme? { Phoneme(rawValue: phonemeCode) }
    var status: ProgressStatus {
        get { ProgressStatus(rawValue: statusRaw) ?? .locked }
        set { statusRaw = newValue.rawValue }
    }
}

/// Avance de una etapa (MVP: Palabras) dentro de un fonema.
@Model
final class StageProgress {
    var id: UUID
    var stageRaw: String          // ver `LearningStage`
    var statusRaw: String         // ver `ProgressStatus`
    var itemsCompleted: Int
    var lastPracticedAt: Date?

    // MARK: - Sincronización (Fase 7.3 · sin sync todavía)
    var updatedAt: Date = Date.distantPast
    var isDirty: Bool = true
    var deletedAt: Date?

    var phonemeProgress: PhonemeProgress?

    init(stage: LearningStage, status: ProgressStatus, itemsCompleted: Int = 0) {
        self.id = UUID()
        self.stageRaw = stage.rawValue
        self.statusRaw = status.rawValue
        self.itemsCompleted = itemsCompleted
        self.lastPracticedAt = nil
        self.updatedAt = Date()
    }

    /// Marca esta etapa como cambiada para el sync futuro (sella `updatedAt`).
    func markDirty() {
        isDirty = true
        updatedAt = Date()
    }

    var stage: LearningStage? { LearningStage(rawValue: stageRaw) }
    var status: ProgressStatus {
        get { ProgressStatus(rawValue: statusRaw) ?? .locked }
        set { statusRaw = newValue.rawValue }
    }
}

/// Construye el árbol de progreso inicial de un perfil nuevo.
///
/// Estado inicial: el primer fonema (orden 0) queda disponible con su etapa de
/// Palabras disponible; todo lo demás bloqueado. Las TRANSICIONES de desbloqueo
/// (completar fonema → abrir el siguiente) se aplican al terminar la práctica;
/// aquí solo se siembra el estado inicial navegable.
enum ProgressFactory {

    static func makeInitialProgress() -> [PhonemeProgress] {
        let phonemes = Phoneme.allCases.sorted { $0.order < $1.order }
        return phonemes.enumerated().map { index, phoneme in
            let isFirstPhoneme = index == 0
            let phonemeProgress = PhonemeProgress(
                phonemeCode: phoneme.code,
                status: isFirstPhoneme ? .available : .locked
            )
            phonemeProgress.stages = LearningStage.mvpFlow.enumerated().map { stageIndex, stage in
                let isFirstStage = stageIndex == 0
                let status: ProgressStatus = (isFirstPhoneme && isFirstStage) ? .available : .locked
                return StageProgress(stage: stage, status: status)
            }
            return phonemeProgress
        }
    }

    /// Crea un perfil ya sembrado con su progreso inicial y lo inserta en el contexto.
    @discardableResult
    static func makeProfile(
        name: String,
        ageBand: AgeBand,
        avatarKey: String = "default",
        in context: ModelContext
    ) -> ChildProfile {
        let profile = ChildProfile(name: name, ageBand: ageBand, avatarKey: avatarKey)
        profile.phonemeProgress = makeInitialProgress()
        context.insert(profile)
        return profile
    }
}
