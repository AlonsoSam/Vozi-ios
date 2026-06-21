import SwiftUI
import SwiftData

/// Historial local de intentos (SwiftData) + exportación CSV.
/// Sin Supabase, sin Auth, sin reportes PDF (fuera del alcance de Fase 0).
struct ResultsListView: View {
    @Query(sort: \SpeechAttempt.timestamp, order: .reverse) private var attempts: [SpeechAttempt]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            if !attempts.isEmpty {
                Section("Resumen") {
                    LabeledContent("Intentos", value: "\(attempts.count)")
                    LabeledContent("Coincidencia algoritmo ↔ adulto", value: agreementText)
                }
            }

            Section("Intentos") {
                if attempts.isEmpty {
                    Text("Aún no hay intentos registrados.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(attempts) { row($0) }
                        .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Resultados")
        .toolbar {
            if !attempts.isEmpty {
                ShareLink(item: AttemptCSV.make(attempts),
                          preview: SharePreview("vozi-fase0-intentos.csv")) {
                    Label("Exportar CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Fila

    private func row(_ a: SpeechAttempt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
            HStack(spacing: 12) {
                Text("sim \(a.similarityScore, format: .number.precision(.fractionLength(2)))")
                Text("umbral \(a.thresholdUsed, format: .number.precision(.fractionLength(2)))")
                Text(a.humanJudgment)
                Text(a.onDevice ? "on-device" : "servidor")
                Text(a.recognizerLocale)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Métrica de validación

    /// % de intentos donde la decisión automática coincide con el juicio del adulto
    /// (humano "pasa" = Correcto o Aceptable).
    private var agreementText: String {
        guard !attempts.isEmpty else { return "—" }
        let agree = attempts.filter { a in
            let humanPass = a.humanJudgment != HumanJudgment.incorrect.rawValue
            return a.algorithmPassed == humanPass
        }.count
        let pct = Double(agree) / Double(attempts.count) * 100
        return String(format: "%.0f%% (%d/%d)", pct, agree, attempts.count)
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(attempts[i]) }
        try? context.save()
    }
}

/// Generador de CSV para análisis fuera de la app (calibración de umbrales).
enum AttemptCSV {
    static func make(_ attempts: [SpeechAttempt]) -> String {
        let header = "timestamp,phoneme,word,stage,transcription,similarity,threshold,algorithmPassed,humanJudgment,durationMs,locale,onDevice,ageBand,evaluationMode,advancedProvider,advancedAccuracy,advancedFluency,advancedCompleteness,evaluatedAt"
        let df = ISO8601DateFormatter()
        let rows = attempts.map { a -> String in
            func num(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "" }
            return [
                df.string(from: a.timestamp),
                a.targetPhoneme,
                a.targetWord,
                a.stage,
                a.rawTranscription.replacingOccurrences(of: ",", with: " "),
                String(format: "%.3f", a.similarityScore),
                String(format: "%.2f", a.thresholdUsed),
                "\(a.algorithmPassed)",
                a.humanJudgment,
                "\(a.durationMs)",
                a.recognizerLocale,
                "\(a.onDevice)",
                a.childAgeBand,
                a.evaluationMode,
                a.advancedProvider ?? "",
                num(a.advancedAccuracy),
                num(a.advancedFluency),
                num(a.advancedCompleteness),
                a.evaluatedAt.map { df.string(from: $0) } ?? ""
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
