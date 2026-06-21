import Foundation
import SwiftData

/// Reglas de avance y desbloqueo de etapas/fonemas (Paso 7).
///
/// NOTA: en Fase 1 esta lógica vive en el cliente y es deliberadamente simple
/// (avance secuencial). Las reglas sensibles de progreso (XP, validación final)
/// migrarán a Edge Functions en fases posteriores (spec §4, §12). Por eso queda
/// aislada en su propio archivo.
enum ProgressService {

    /// Puntos de gamificación otorgados por cada lista de fonema/grupo terminada
    /// (Fase 4). Recompensa visual; no afecta la evaluación. Cuando llegue la fase
    /// Supabase, esta regla sensible debe migrar a Edge Functions.
    static let pointsPerCompletion = 10

    /// Marca una etapa como completada y desbloquea la siguiente. Si era la
    /// última etapa del fonema (MVP: Palabras), marca el fonema como completado y
    /// desbloquea el primer fonema siguiente. Idempotente: solo pasa de
    /// `locked` a `available`, nunca regresa estados.
    ///
    /// Gamificación (Fase 4): la recompensa (sumar `completionCount` y otorgar
    /// `pointsPerCompletion`) se aplica SOLO si `rewarded == true`, es decir, si la
    /// sesión alcanzó el 90% de aciertos (lo decide el ViewModel). El desbloqueo
    /// educativo del siguiente fonema NO se gatea: ocurre al terminar la lista para
    /// no frustrar el flujo de práctica. NO cambia la evaluación por palabra.
    static func completeStage(_ stageProgress: StageProgress,
                              rewarded: Bool,
                              in context: ModelContext) {
        stageProgress.status = .completed
        stageProgress.lastPracticedAt = Date()

        guard let phonemeProgress = stageProgress.phonemeProgress else {
            try? context.save()
            return
        }

        // Gamificación: solo con sesión recompensada (≥90% de aciertos).
        if rewarded {
            phonemeProgress.completionCount += 1
            phonemeProgress.child?.points += pointsPerCompletion
        }

        let stages = sortedStages(phonemeProgress.stages)
        if let idx = stages.firstIndex(where: { $0.id == stageProgress.id }),
           idx + 1 < stages.count {
            unlock(stages[idx + 1])
        }

        // Fonema completo si todas sus etapas están completas.
        if stages.allSatisfy({ $0.status == .completed }) {
            phonemeProgress.status = .completed
            unlockNextPhoneme(after: phonemeProgress)
        }

        try? context.save()
    }

    /// Registra una práctica de etapa (actualiza marca de tiempo) sin completarla.
    static func touch(_ stageProgress: StageProgress, in context: ModelContext) {
        stageProgress.lastPracticedAt = Date()
        try? context.save()
    }

    // MARK: - Privados

    private static func unlock(_ stage: StageProgress) {
        if stage.status == .locked { stage.status = .available }
    }

    private static func unlockNextPhoneme(after phonemeProgress: PhonemeProgress) {
        guard let child = phonemeProgress.child else { return }
        let phonemes = child.phonemeProgress.sorted {
            ($0.phoneme?.order ?? .max) < ($1.phoneme?.order ?? .max)
        }
        guard let idx = phonemes.firstIndex(where: { $0.id == phonemeProgress.id }),
              idx + 1 < phonemes.count else { return }

        let next = phonemes[idx + 1]
        if next.status == .locked { next.status = .available }
        if let firstStage = sortedStages(next.stages).first {
            unlock(firstStage)
        }
    }

    private static func sortedStages(_ stages: [StageProgress]) -> [StageProgress] {
        let order = LearningStage.allCases
        return stages.sorted {
            (order.firstIndex(of: $0.stage ?? .palabras) ?? .max)
                < (order.firstIndex(of: $1.stage ?? .palabras) ?? .max)
        }
    }
}
