import SwiftUI
import SwiftData

// VOZI iOS — Fase 0 (Validación Speech-to-Text)
// Herramienta de validación operada por un adulto. No es la app infantil final.
@main
struct VoziIOSApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // SwiftData: persistencia local de los intentos de prueba.
        .modelContainer(for: SpeechAttempt.self)
    }
}
