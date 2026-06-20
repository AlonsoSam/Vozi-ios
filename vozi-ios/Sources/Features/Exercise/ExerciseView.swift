import SwiftUI
import SwiftData

/// Pantalla de ejercicio reutilizable. Resuelve el contenido de la etapa desde
/// `ContentBank` y elige la sub-vista según el tipo de etapa:
///  - Escuchar (sin micrófono) → `ListenExerciseView`.
///  - Sílabas/Palabras/Frases/Misión (con voz) → `SpeakingExerciseView`.
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
                if content.usesMicrophone {
                    SpeakingExerciseView(content: content, phoneme: phoneme, stageProgress: stageProgress)
                } else {
                    ListenExerciseView(content: content, stageProgress: stageProgress)
                }
            } else {
                ContentUnavailableView("Sin contenido", systemImage: "questionmark")
            }
        }
        .navigationTitle(stage?.rawValue ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Etapa Escuchar: el niño escucha el modelo (TTS) ítem por ítem. Sin micrófono.
/// Botones grandes, un ítem a la vez, narración por audio (spec §11).
private struct ListenExerciseView: View {
    let content: StageContent
    let stageProgress: StageProgress

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var index = 0
    @State private var voice = ModelVoiceService()

    private var item: ContentItem { content.items[index] }
    private var isLast: Bool { index >= content.items.count - 1 }
    private var isFirst: Bool { index == 0 }

    var body: some View {
        VStack(spacing: 28) {
            Text("\(index + 1) de \(content.items.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(item.text)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                voice.speak(item.text)
            } label: {
                Label("Escuchar", systemImage: voice.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    if !isFirst { index -= 1 }
                } label: {
                    Label("Anterior", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(isFirst)

                if isLast {
                    Button {
                        voice.stop()
                        ProgressService.completeStage(stageProgress, in: context)
                        dismiss()
                    } label: {
                        Label("¡Listo!", systemImage: "checkmark")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        index += 1
                    } label: {
                        Label("Siguiente", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .onAppear { voice.speak(item.text) }
        .onChange(of: index) { _, _ in voice.speak(item.text) }
        .onDisappear { voice.stop() }
    }
}
