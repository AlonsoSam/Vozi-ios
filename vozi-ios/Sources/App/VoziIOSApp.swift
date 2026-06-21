import SwiftUI
import SwiftData

// VOZI iOS — App educativa (MVP: práctica de Palabras por fonema/grupo)
@main
struct VoziIOSApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
