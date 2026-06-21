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
            }
            .navigationTitle("Panel de adultos")
            .navigationDestination(for: ChildProfile.self) { profile in
                ParentProfileDetailView(profile: profile)
            }
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
