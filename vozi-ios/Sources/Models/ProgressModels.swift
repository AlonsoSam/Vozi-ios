import Foundation
import SwiftData

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
    }

    var ageBand: AgeBand { AgeBand(rawValue: ageBandRaw) ?? .young }
}

/// Avance de un fonema concreto para un perfil.
@Model
final class PhonemeProgress {
    var id: UUID
    var phonemeCode: String       // "R", "RR", "S", "L", "TR"
    var statusRaw: String         // ver `ProgressStatus`

    var child: ChildProfile?

    /// Avance de las 5 etapas de este fonema. Cascade desde el fonema.
    @Relationship(deleteRule: .cascade, inverse: \StageProgress.phonemeProgress)
    var stages: [StageProgress] = []

    init(phonemeCode: String, status: ProgressStatus) {
        self.id = UUID()
        self.phonemeCode = phonemeCode
        self.statusRaw = status.rawValue
    }

    var phoneme: Phoneme? { Phoneme(rawValue: phonemeCode) }
    var status: ProgressStatus {
        get { ProgressStatus(rawValue: statusRaw) ?? .locked }
        set { statusRaw = newValue.rawValue }
    }
}

/// Avance de una etapa (Escuchar/Sílabas/Palabras/Frases/Misión) dentro de un fonema.
@Model
final class StageProgress {
    var id: UUID
    var stageRaw: String          // ver `LearningStage`
    var statusRaw: String         // ver `ProgressStatus`
    var itemsCompleted: Int
    var lastPracticedAt: Date?

    var phonemeProgress: PhonemeProgress?

    init(stage: LearningStage, status: ProgressStatus, itemsCompleted: Int = 0) {
        self.id = UUID()
        self.stageRaw = stage.rawValue
        self.statusRaw = status.rawValue
        self.itemsCompleted = itemsCompleted
        self.lastPracticedAt = nil
    }

    var stage: LearningStage? { LearningStage(rawValue: stageRaw) }
    var status: ProgressStatus {
        get { ProgressStatus(rawValue: statusRaw) ?? .locked }
        set { statusRaw = newValue.rawValue }
    }
}

/// Construye el árbol de progreso inicial de un perfil nuevo.
///
/// Estado inicial: el primer fonema (orden 0) queda disponible con su primera
/// etapa (Escuchar) disponible; todo lo demás bloqueado. Las TRANSICIONES de
/// desbloqueo (completar etapa → abrir la siguiente) son del Paso 7; aquí solo
/// se siembra el estado inicial navegable.
enum ProgressFactory {

    static func makeInitialProgress() -> [PhonemeProgress] {
        let phonemes = Phoneme.allCases.sorted { $0.order < $1.order }
        return phonemes.enumerated().map { index, phoneme in
            let isFirstPhoneme = index == 0
            let phonemeProgress = PhonemeProgress(
                phonemeCode: phoneme.code,
                status: isFirstPhoneme ? .available : .locked
            )
            phonemeProgress.stages = LearningStage.allCases.enumerated().map { stageIndex, stage in
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
