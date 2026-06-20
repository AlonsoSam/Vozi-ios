import SwiftUI
import SwiftData

/// Detalle de progreso de un perfil para el adulto (spec §13):
/// resumen, progreso por fonema, intentos con juicio adulto y export CSV.
/// El juicio adulto es la validación final (spec §7); el STT base es solo
/// coincidencia aproximada.
struct ParentProfileDetailView: View {
    let profile: ChildProfile
    @Environment(\.modelContext) private var context

    private var attempts: [SpeechAttempt] {
        profile.attempts.sorted { $0.timestamp > $1.timestamp }
    }
    private var practiceMinutes: Int {
        profile.attempts.reduce(0) { $0 + $1.durationMs } / 60000
    }
    private var pendingCount: Int {
        profile.attempts.filter { $0.humanJudgment.isEmpty }.count
    }

    var body: some View {
        List {
            Section("Resumen") {
                LabeledContent("Intentos", value: "\(profile.attempts.count)")
                LabeledContent("Tiempo de práctica", value: "\(practiceMinutes) min")
                LabeledContent("Por validar", value: "\(pendingCount)")
            }

            Section("Progreso por fonema") {
                ForEach(orderedPhonemes) { pp in
                    phonemeRow(pp)
                }
            }

            Section("Intentos") {
                if attempts.isEmpty {
                    Text("Aún no hay intentos.").foregroundStyle(.secondary)
                } else {
                    ForEach(attempts) { attemptRow($0) }
                }
            }
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !attempts.isEmpty {
                ShareLink(item: AttemptCSV.make(attempts),
                          preview: SharePreview("vozi-\(profile.name)-intentos.csv")) {
                    Label("Exportar CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var orderedPhonemes: [PhonemeProgress] {
        profile.phonemeProgress.sorted { ($0.phoneme?.order ?? .max) < ($1.phoneme?.order ?? .max) }
    }

    private func phonemeRow(_ pp: PhonemeProgress) -> some View {
        let stagesDone = pp.stages.filter { $0.status == .completed }.count
        return HStack {
            Image(systemName: pp.phoneme?.iconSystemName ?? "questionmark")
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(pp.phoneme?.displayName ?? "—").bold()
            Spacer()
            Text("\(stagesDone)/\(LearningStage.allCases.count) etapas")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if pp.status == .completed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
    }

    private func attemptRow(_ a: SpeechAttempt) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(a.targetPhoneme) · \(a.targetWord)").bold()
                Spacer()
                Text(a.algorithmPassed ? "AUTO ✓" : "AUTO ✗")
                    .font(.caption)
                    .foregroundStyle(a.algorithmPassed ? .green : .orange)
            }
            Text("«\(a.rawTranscription.isEmpty ? "—" : a.rawTranscription)»")
                .font(.callout)
                .foregroundStyle(.secondary)

            // Juicio del adulto (validación final).
            Menu {
                Button("Pendiente") { setJudgment(a, "") }
                ForEach(HumanJudgment.allCases) { j in
                    Button(j.rawValue) { setJudgment(a, j.rawValue) }
                }
            } label: {
                Label(a.humanJudgment.isEmpty ? "Validar" : a.humanJudgment,
                      systemImage: "person.fill.checkmark")
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    private func setJudgment(_ attempt: SpeechAttempt, _ value: String) {
        attempt.humanJudgment = value
        try? context.save()
    }
}
