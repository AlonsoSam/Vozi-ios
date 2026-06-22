import SwiftUI
import SwiftData

/// Detalle de progreso de un perfil para el adulto (spec §13):
/// resumen, progreso por fonema e intentos con juicio adulto.
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
            Section {
                HStack(spacing: VoziTheme.Space.sm) {
                    summaryPill("waveform", "\(profile.attempts.count)", "intentos", VoziTheme.brand)
                    summaryPill("clock.fill", "\(practiceMinutes)", "min", VoziTheme.mint)
                    summaryPill("person.fill.checkmark", "\(pendingCount)", "por validar", VoziTheme.almost)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            } header: {
                sectionHeader("Resumen")
            }

            Section {
                ForEach(orderedPhonemes) { pp in
                    phonemeRow(pp)
                }
            } header: {
                sectionHeader("Progreso por fonema")
            }

            Section {
                if attempts.isEmpty {
                    Text("Aún no hay intentos.")
                        .font(.vozi(.subheadline))
                        .foregroundStyle(VoziTheme.inkSoft)
                } else {
                    ForEach(attempts) { attemptRow($0) }
                }
            } header: {
                sectionHeader("Intentos")
            }
        }
        .scrollContentBackground(.hidden)
        .voziBackground()
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.vozi(.subheadline, weight: .bold))
            .foregroundStyle(VoziTheme.ink)
            .textCase(nil)
    }

    private func summaryPill(_ symbol: String, _ value: String, _ caption: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.vozi(.title3, weight: .bold))
                .foregroundStyle(VoziTheme.ink)
            Text(caption)
                .font(.vozi(.caption2))
                .foregroundStyle(VoziTheme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VoziTheme.Space.md)
        .voziCard(cornerRadius: VoziTheme.Radius.md)
    }

    private var orderedPhonemes: [PhonemeProgress] {
        profile.phonemeProgress.sorted { ($0.phoneme?.order ?? .max) < ($1.phoneme?.order ?? .max) }
    }

    private func phonemeRow(_ pp: PhonemeProgress) -> some View {
        let stagesDone = pp.stages.filter { $0.status == .completed }.count
        let color = pp.phoneme.map(VoziTheme.color(for:)) ?? VoziTheme.brand
        return HStack(spacing: VoziTheme.Space.md) {
            Image(systemName: pp.phoneme?.iconSystemName ?? "questionmark")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(VoziTheme.gradient(color), in: Circle())
            Text(pp.phoneme?.displayName ?? "—")
                .font(.vozi(.headline, weight: .bold))
                .foregroundStyle(VoziTheme.ink)
            Spacer()
            Text("\(stagesDone)/\(LearningStage.allCases.count) etapas")
                .font(.vozi(.subheadline, weight: .medium))
                .foregroundStyle(VoziTheme.inkSoft)
            if pp.status == .completed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(VoziTheme.success)
            }
        }
        .listRowBackground(rowBackground)
    }

    private func attemptRow(_ a: SpeechAttempt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(a.targetPhoneme) · \(a.targetWord)")
                    .font(.vozi(.headline, weight: .bold))
                    .foregroundStyle(VoziTheme.ink)
                Spacer()
                Label(a.algorithmPassed ? "Auto ✓" : "Auto ✗", systemImage: "cpu")
                    .font(.vozi(.caption2, weight: .bold))
                    .foregroundStyle(a.algorithmPassed ? VoziTheme.success : VoziTheme.almost)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background((a.algorithmPassed ? VoziTheme.success : VoziTheme.almost).opacity(0.15),
                                in: Capsule())
            }
            Text("«\(a.rawTranscription.isEmpty ? "—" : a.rawTranscription)»")
                .font(.vozi(.callout))
                .foregroundStyle(VoziTheme.inkSoft)

            // Juicio del adulto (validación final).
            Menu {
                Button("Pendiente") { setJudgment(a, "") }
                ForEach(HumanJudgment.allCases) { j in
                    Button(j.rawValue) { setJudgment(a, j.rawValue) }
                }
            } label: {
                Label(a.humanJudgment.isEmpty ? "Validar" : a.humanJudgment,
                      systemImage: "person.fill.checkmark")
                    .font(.vozi(.subheadline, weight: .semibold))
                    .foregroundStyle(a.humanJudgment.isEmpty ? VoziTheme.brand : VoziTheme.success)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background((a.humanJudgment.isEmpty ? VoziTheme.brand : VoziTheme.success).opacity(0.12),
                                in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(rowBackground)
    }

    /// Fondo de fila tipo tarjeta sobre el degradado VOZI.
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous)
            .fill(VoziTheme.cardFill)
            .padding(.vertical, 3)
    }

    private func setJudgment(_ attempt: SpeechAttempt, _ value: String) {
        attempt.humanJudgment = value
        attempt.markDirty()   // Fase 7.3: juicio del adulto → pendiente de sincronizar.
        try? context.save()
    }
}
