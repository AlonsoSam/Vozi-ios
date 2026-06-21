import SwiftUI
import SwiftData

/// Etapa de práctica con voz: el niño escucha el modelo y habla; el STT
/// on-device + `ApproximateMatcher` dan coincidencia aproximada con feedback
/// positivo. Sirve para Sílabas, Palabras, Frases y Misión.
struct SpeakingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let stageProgress: StageProgress
    private let isMission: Bool
    @State private var vm: SpeakingExerciseViewModel

    init(content: StageContent, phoneme: Phoneme, stageProgress: StageProgress) {
        self.stageProgress = stageProgress
        self.isMission = stageProgress.stage == .mision
        _vm = State(initialValue: SpeakingExerciseViewModel(
            content: content,
            phoneme: phoneme,
            profile: stageProgress.phonemeProgress?.child
        ))
    }

    var body: some View {
        Group {
            if vm.finished {
                completionView
            } else {
                exerciseView
            }
        }
        .onDisappear { vm.stopAll() }
    }

    // MARK: - Ejercicio

    private var exerciseView: some View {
        VStack(spacing: 24) {
            Text("\(vm.index + 1) de \(vm.totalItems)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            WordImageView(imageKey: vm.item.imageKey)

            Text(vm.item.text)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(.horizontal)

            Button { vm.playModel() } label: {
                Label("Escuchar", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(vm.isRecording)

            Spacer()

            if vm.isEvaluating {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Escuchando con atención…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if vm.showResult {
                feedbackPanel
            } else {
                micButton
            }
        }
        .padding(.vertical)
        .navigationBarBackButtonHidden(vm.isRecording)
    }

    private var micButton: some View {
        VStack(spacing: 12) {
            Button { vm.micTapped(context: context) } label: {
                Label(vm.isRecording ? "Detener" : "Hablar",
                      systemImage: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRecording ? .red : .accentColor)

            Text(vm.isRecording ? "Te escucho…" : "Toca y dilo en voz alta")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var feedbackPanel: some View {
        // Tres estados: aprobado, "te escuché pero sin puntaje" (modo avanzado sin
        // score útil) y "casi". Sin números ni lenguaje clínico para el niño.
        let icon = vm.passed ? "star.circle.fill"
            : (vm.heardButNoScore ? "waveform.circle.fill" : "hand.thumbsup.circle.fill")
        let tint: Color = vm.passed ? .green : (vm.heardButNoScore ? .blue : .orange)
        let title: String = {
            if vm.passed { return "¡Muy bien!" }
            if vm.lastPhonemeMissed { return "Casi, intentemos escuchar bien ese sonido." }
            if vm.heardButNoScore { return "Te escuché, intentemos una vez más" }
            return "¡Casi! Sigue practicando"
        }()

        return VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !vm.passed {
                Button { vm.playModel() } label: {
                    Label("Escuchar pista", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button { vm.retry() } label: {
                    Label("Otra vez", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button { vm.advance() } label: {
                    Label(vm.isLastItem ? "Terminar" : "Siguiente",
                          systemImage: vm.isLastItem ? "checkmark" : "chevron.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - Completado (Paso 8: celebración, con variante de Misión)

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: isMission ? "flag.checkered.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text(isMission ? "¡Misión cumplida!" : "¡Etapa completada!")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Buen trabajo. Tu progreso quedó guardado.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                ProgressService.completeStage(stageProgress, in: context)
                dismiss()
            } label: {
                Text("¡Listo!")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}
