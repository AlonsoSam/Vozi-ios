import SwiftUI
import SwiftData

/// Pantalla de ejercicio del MVP. Resuelve el contenido de Palabras desde
/// `ContentBank` y lo entrega a `SpeakingExerciseView` (práctica con voz).
struct ExerciseView: View {
    let stageProgress: StageProgress

    private var phoneme: Phoneme? { stageProgress.phonemeProgress?.phoneme }
    private var stage: LearningStage? { stageProgress.stage }
    private var content: StageContent? {
        guard let phoneme, let stage else { return nil }
        return ContentBank.stage(stage, for: phoneme)
    }

    var body: some View {
        Group {
            if let content, let phoneme {
                SpeakingExerciseView(content: content, phoneme: phoneme, stageProgress: stageProgress)
            } else {
                ContentUnavailableView("Sin contenido", systemImage: "questionmark")
            }
        }
        .navigationTitle(stage?.rawValue ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}
