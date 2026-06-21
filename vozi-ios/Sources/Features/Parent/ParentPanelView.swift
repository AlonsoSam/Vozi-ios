import SwiftUI
import SwiftData

/// Panel mínimo de padres (spec §13): lista de perfiles con resumen de progreso.
/// Tocar un perfil abre su detalle (progreso, intentos, juicio adulto, CSV).
/// Local/offline; sin Supabase ni reportes PDF (fases posteriores).
struct ParentPanelView: View {
    @Query(sort: \ChildProfile.createdAt, order: .forward) private var profiles: [ChildProfile]

    var body: some View {
        NavigationStack {
            List {
                Section("Perfiles") {
                    if profiles.isEmpty {
                        Text("Aún no hay perfiles. Crea uno en la pestaña Perfiles.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(profiles) { profile in
                            NavigationLink(value: profile) {
                                ParentProfileRow(profile: profile)
                            }
                        }
                    }
                }

                AdvancedEvaluationSection()
            }
            .navigationTitle("Panel de adultos")
            .navigationDestination(for: ChildProfile.self) { profile in
                ParentProfileDetailView(profile: profile)
            }
        }
    }
}

/// Sección de consentimiento para la evaluación avanzada (spec §6/§7).
///
/// Apagada por defecto. Al activar pide confirmación; al desactivar apaga el modo
/// avanzado de inmediato (el siguiente intento vuelve al modo base). Muestra el
/// estado de Azure (configurado / no configurado) sin exponer la key.
private struct AdvancedEvaluationSection: View {
    @AppStorage(AdvancedConsentStore.defaultsKey) private var consentGranted = false
    @State private var showEnableConfirm = false

    /// La función está habilitada solo si el flag maestro lo permite (en el MVP
    /// está desactivada: la evaluación principal es por palabras con STT base).
    private var featureEnabled: Bool { AdvancedConsentStore.featureEnabled }

    /// Modo efectivo de práctica: avanzado solo si la función está habilitada,
    /// Azure configurado y hay consentimiento. (Refleja `SpeakingExerciseViewModel`.)
    private var advancedActive: Bool {
        featureEnabled && AzureSecrets.isConfigured && consentGranted
    }

    var body: some View {
        Section {
            Toggle("Activar evaluación avanzada", isOn: toggleBinding)
                .controlSize(.large)
                .disabled(!featureEnabled)

            if !featureEnabled {
                Text("Función experimental, desactivada en esta versión del MVP. La práctica usa la evaluación por palabras en el dispositivo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            statusRow("Servicio",
                      AzureSecrets.isConfigured ? "Configurado" : "No configurado",
                      AzureSecrets.isConfigured ? .green : .secondary)
            statusRow("Consentimiento",
                      consentGranted ? "Activado" : "Desactivado",
                      consentGranted ? .green : .secondary)
            statusRow("Modo actual",
                      advancedActive ? "Avanzado" : "Base",
                      advancedActive ? .green : .orange)

            VStack(alignment: .leading, spacing: 6) {
                bullet("Es una evaluación educativa y referencial, no un diagnóstico clínico.")
                bullet("Usa clips de audio cortos y temporales solo para evaluar.")
                bullet("No guarda audio crudo del niño.")
                bullet("Si el servicio no está disponible, usa el modo base en el dispositivo.")
                bullet("Requiere tu consentimiento como adulto y está apagada por defecto.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
        } header: {
            Text("Evaluación avanzada (experimental)")
        }
        .alert("Activar evaluación avanzada", isPresented: $showEnableConfirm) {
            Button("Cancelar", role: .cancel) { }
            Button("Activar") { consentGranted = true }
        } message: {
            Text("La práctica usará clips cortos temporales para una evaluación educativa y referencial. No se guarda audio crudo. Puedes desactivarla cuando quieras.")
        }
    }

    /// Activar → pide confirmación (no se compromete hasta aceptar).
    /// Desactivar → apaga de inmediato.
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { consentGranted },
            set: { newValue in
                if newValue {
                    showEnableConfirm = true
                } else {
                    consentGranted = false
                }
            }
        )
    }

    private func statusRow(_ title: String, _ value: String, _ tint: Color) -> some View {
        LabeledContent(title) {
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
    }
}

/// Fila-resumen de un perfil en el panel.
private struct ParentProfileRow: View {
    let profile: ChildProfile

    private var phonemesCompleted: Int {
        profile.phonemeProgress.filter { $0.status == .completed }.count
    }
    private var stagesCompleted: Int {
        profile.phonemeProgress.flatMap { $0.stages }.filter { $0.status == .completed }.count
    }

    var body: some View {
        let avatar = AvatarCatalog.option(for: profile.avatarKey)
        HStack(spacing: 14) {
            Image(systemName: avatar.symbol)
                .font(.title2)
                .foregroundStyle(avatar.tint)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).font(.headline)
                Text("\(profile.ageBand.rawValue) años · \(phonemesCompleted) fonemas · \(stagesCompleted) etapas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
