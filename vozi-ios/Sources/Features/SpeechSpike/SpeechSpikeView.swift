import SwiftUI
import SwiftData
import AVFoundation

/// Pantalla principal de la Fase 0. Operada por un adulto: NO es UX infantil final.
struct SpeechSpikeView: View {
    @State private var vm = SpeechSpikeViewModel()
    @Environment(\.modelContext) private var context
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            Form {
                configSection
                recordSection
                if vm.hasResult { resultSection }
                navSection
            }
            .navigationTitle("Prueba STT · Fase 0")
        }
    }

    // MARK: - Configuración (adulto)

    private var configSection: some View {
        Section("Configuración (adulto)") {
            Picker("Fonema", selection: $vm.selectedPhoneme) {
                ForEach(PromptBank.phonemes, id: \.self) { Text($0) }
            }
            .onChange(of: vm.selectedPhoneme) { _, _ in vm.refreshPromptForPhoneme() }

            Picker("Palabra objetivo", selection: $vm.selectedPrompt) {
                ForEach(vm.prompts) { prompt in
                    Text("\(prompt.word)  ·  \(prompt.stage.rawValue)").tag(prompt)
                }
            }

            Picker("Idioma (locale)", selection: $vm.selectedLocaleID) {
                ForEach(vm.availableLocales) { Text($0.label).tag($0.id) }
            }

            Picker("Edad", selection: $vm.ageBand) {
                ForEach(AgeBand.allCases) { Text($0.rawValue).tag($0) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Umbral de acierto: \(vm.threshold, format: .number.precision(.fractionLength(2)))")
                Slider(value: $vm.threshold, in: 0.3...1.0, step: 0.05)
            }
        }
    }

    // MARK: - Grabación

    private var recordSection: some View {
        Section {
            Button {
                speakTarget()
            } label: {
                Label("Escuchar palabra modelo", systemImage: "speaker.wave.2.fill")
            }
            .disabled(vm.isRecording)

            Button {
                vm.toggleRecording()
            } label: {
                Label(vm.isRecording ? "Detener" : "Grabar",
                      systemImage: vm.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRecording ? .red : .accentColor)

            if !vm.liveTranscription.isEmpty {
                LabeledContent("Transcripción", value: vm.liveTranscription)
            }
            if let err = vm.lastError,
               vm.liveTranscription.isEmpty,
               !vm.hasResult {
                Text(err).font(.footnote).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Resultado + juicio del adulto

    private var resultSection: some View {
        Section("Resultado") {
            if let r = vm.lastResult {
                LabeledContent("Similitud",
                               value: r.score.formatted(.number.precision(.fractionLength(2))))
                ProgressView(value: r.score)
                LabeledContent("Decisión automática") {
                    Text(r.passed ? "ACIERTO" : "FALLO")
                        .bold()
                        .foregroundStyle(r.passed ? .green : .orange)
                }
            }

            LabeledContent("Reconocimiento",
                           value: vm.usedOnDevice ? "On-device ✓" : "Servidor (fallback) ⚠︎")
            if !vm.usedOnDevice {
                Text("On-device no disponible para este idioma; iOS usó reconocimiento por servidor. VOZI no guarda audio.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Juicio del adulto:").font(.subheadline)
            HStack(spacing: 8) {
                ForEach(HumanJudgment.allCases) { judgment in
                    Button(judgment.rawValue) {
                        vm.save(judgment: judgment, context: context)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Navegación

    private var navSection: some View {
        Section {
            NavigationLink {
                ResultsListView()
            } label: {
                Label("Ver resultados / exportar", systemImage: "list.bullet.rectangle")
            }
        }
    }

    // MARK: - Narración modelo (TTS)

    private func speakTarget() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: .duckOthers)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: vm.selectedPrompt.word)
        utterance.voice = AVSpeechSynthesisVoice(language: vm.selectedLocaleID)
        synthesizer.speak(utterance)
    }

    // MARK: - Color del juicio del adulto

    private func judgmentTint(_ judgment: HumanJudgment) -> Color {
        switch judgment {
        case .correct:
            return .green
        case .acceptable:
            return .orange
        case .incorrect:
            return .red
        }
    }
}
