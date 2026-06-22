import Foundation
import SwiftData

/// Utilidad de desarrollo para limpiar datos locales de prueba (Fase 7.7+).
///
/// Borra TODO el contenido local de SwiftData: intentos y perfiles (con su
/// progreso por cascade), dejando la app como nueva localmente. Es 100% LOCAL:
/// NO hace ninguna llamada a Supabase, NO borra datos remotos y NO toca el esquema
/// remoto. Tampoco sube nada antes de borrar.
enum DeveloperDataReset {

    /// Elimina perfiles, progreso e intentos locales. No sincroniza nada.
    ///
    /// Orden: primero `SpeechAttempt` (su relación con el perfil es `.nullify`, así
    /// que no se borran al borrar el perfil) y luego `ChildProfile` (cascade borra
    /// `PhonemeProgress` y `StageProgress`).
    static func wipeLocalData(in context: ModelContext) {
        for attempt in (try? context.fetch(FetchDescriptor<SpeechAttempt>())) ?? [] {
            context.delete(attempt)
        }
        for profile in (try? context.fetch(FetchDescriptor<ChildProfile>())) ?? [] {
            context.delete(profile)   // cascade: PhonemeProgress + StageProgress
        }
        try? context.save()
    }
}
