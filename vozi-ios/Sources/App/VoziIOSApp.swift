import SwiftUI
import SwiftData

// VOZI iOS — App educativa (MVP: práctica de Palabras por fonema/grupo)
@main
struct VoziIOSApp: App {
    /// Estado global de Premium simulado (Fase 6), persistido en UserDefaults.
    @StateObject private var premium = PremiumStore()

    /// Autenticación del adulto (Fase 7.2). Local-first: si no hay sesión, la app
    /// funciona igual. Restaura la sesión persistida al arrancar.
    @StateObject private var auth = AuthService()

    /// Sincronización con Supabase (Fase 7.4: solo children). No-op sin sesión.
    @StateObject private var sync = SyncService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(premium)
                .environmentObject(auth)
                .environmentObject(sync)
                // VOZI prioriza el aspecto claro (app educativa infantil): se fija el
                // modo claro y el acento de marca para una identidad consistente.
                .tint(VoziTheme.brand)
                .preferredColorScheme(.light)
        }
        // SwiftData: persistencia local (perfiles, progreso e intentos).
        .modelContainer(for: [
            ChildProfile.self,
            PhonemeProgress.self,
            StageProgress.self,
            SpeechAttempt.self,
        ])
    }
}
