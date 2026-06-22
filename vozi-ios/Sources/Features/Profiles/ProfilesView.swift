import SwiftUI
import SwiftData

/// Entrada de Fase 1: el adulto elige un perfil de niño o crea uno nuevo (spec §5).
/// Tocar un perfil entra a su Home (Paso 4). Editar/eliminar vía menú contextual (adulto).
struct ProfilesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChildProfile.createdAt, order: .forward) private var profiles: [ChildProfile]

    @State private var editingProfile: ChildProfile?
    @State private var showingNew = false
    @State private var profileToDelete: ChildProfile?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 20)]

    var body: some View {
        NavigationStack {
            Group {
                if profiles.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .voziBackground()
            .navigationTitle("¿Quién va a practicar?")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: {
                        Label("Nuevo perfil", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: ChildProfile.self) { profile in
                ChildHomeView(profile: profile)
            }
            .sheet(isPresented: $showingNew) {
                ProfileEditorView()
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditorView(profile: profile)
            }
            .confirmationDialog(
                "¿Eliminar este perfil?",
                isPresented: .init(
                    get: { profileToDelete != nil },
                    set: { if !$0 { profileToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar", role: .destructive) {
                    if let profileToDelete { delete(profileToDelete) }
                }
                Button("Cancelar", role: .cancel) { profileToDelete = nil }
            } message: {
                Text("Se borrará el progreso de este perfil. Los intentos guardados se conservan para análisis.")
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(profiles) { profile in
                    NavigationLink(value: profile) {
                        ProfileTile(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editingProfile = profile } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        Button(role: .destructive) { profileToDelete = profile } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            VoziEmptyState(
                symbol: "person.crop.circle.badge.plus",
                title: "Aún no hay perfiles",
                message: "Crea un perfil para empezar a practicar.",
                color: VoziTheme.mint,
                actionTitle: "Crear perfil",
                action: { showingNew = true }
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func delete(_ profile: ChildProfile) {
        context.delete(profile)
        try? context.save()
        profileToDelete = nil
    }
}

/// Tarjeta grande y clara de un perfil (botones grandes, spec §11).
private struct ProfileTile: View {
    let profile: ChildProfile

    var body: some View {
        let avatar = AvatarCatalog.option(for: profile.avatarKey)
        VStack(spacing: VoziTheme.Space.md) {
            VoziHeroIcon(symbol: avatar.symbol, color: avatar.tint, size: 88)
            Text(profile.name)
                .font(.vozi(.title3, weight: .bold))
                .foregroundStyle(VoziTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(profile.ageBand.rawValue) años")
                .font(.vozi(.subheadline, weight: .semibold))
                .foregroundStyle(avatar.tint)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(avatar.tint.opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VoziTheme.Space.lg)
        .voziCard()
    }
}
