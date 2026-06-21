import SwiftUI
import SwiftData

/// Detalle de un fonema: el flujo MVP en orden (Escuchar → Palabras) con su
/// estado. Las etapas no bloqueadas navegan al ejercicio.
struct PhonemeDetailView: View {
    let progress: PhonemeProgress

    /// Etapas del flujo MVP (Escuchar, Palabras), en orden. Filtra cualquier
    /// etapa fuera del flujo (p. ej. datos previos con Sílabas/Frases/Misión).
    private var orderedStages: [StageProgress] {
        let order = LearningStage.mvpFlow
        return progress.stages
            .filter { stage in order.contains(where: { $0 == stage.stage }) }
            .sorted {
                (order.firstIndex(of: $0.stage ?? .escuchar) ?? .max)
                    < (order.firstIndex(of: $1.stage ?? .escuchar) ?? .max)
            }
    }

    var body: some View {
        List {
            Section {
                ForEach(orderedStages) { stageProgress in
                    if stageProgress.status == .locked {
                        StageRow(stageProgress: stageProgress)
                    } else {
                        NavigationLink(value: stageProgress) {
                            StageRow(stageProgress: stageProgress)
                        }
                    }
                }
            } footer: {
                Text("Practica las etapas en orden. Completar una abre la siguiente.")
            }
        }
        .navigationTitle(progress.phoneme?.displayName ?? "Fonema")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: StageProgress.self) { stageProgress in
            ExerciseView(stageProgress: stageProgress)
        }
    }
}

/// Fila de una etapa con icono, nombre y estado.
private struct StageRow: View {
    let stageProgress: StageProgress

    var body: some View {
        let stage = stageProgress.stage
        let status = stageProgress.status

        HStack(spacing: 16) {
            Image(systemName: icon(for: stage))
                .font(.title2)
                .foregroundStyle(status == .locked ? Color.secondary : .accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage?.rawValue ?? "—")
                    .font(.headline)
                Text(statusText(status))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            statusIcon(status)
        }
        .padding(.vertical, 6)
        .opacity(status == .locked ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    private func icon(for stage: LearningStage?) -> String {
        switch stage {
        case .escuchar: return "ear.fill"
        case .silabas:  return "textformat.abc"
        case .palabras: return "text.bubble.fill"
        case .frases:   return "text.quote"
        case .mision:   return "flag.checkered"
        case .none:     return "questionmark"
        }
    }

    private func statusText(_ status: ProgressStatus) -> String {
        switch status {
        case .locked:    return "Bloqueada"
        case .available: return "Disponible"
        case .completed: return "Completada"
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: ProgressStatus) -> some View {
        switch status {
        case .locked:    Image(systemName: "lock.fill").foregroundStyle(.secondary)
        case .available: EmptyView()  // el chevron lo aporta el NavigationLink
        case .completed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}
