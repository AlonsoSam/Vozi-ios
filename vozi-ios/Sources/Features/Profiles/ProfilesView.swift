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
        ContentUnavailableView {
            Label("Aún no hay perfiles", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Crea un perfil para empezar a practicar.")
        } actions: {
            Button("Crear perfil") { showingNew = true }
                .buttonStyle(.borderedProminent)
        }
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
        VStack(spacing: 12) {
            Image(systemName: avatar.symbol)
                .font(.system(size: 44))
                .foregroundStyle(avatar.tint)
                .frame(width: 96, height: 96)
                .background(avatar.tint.opacity(0.15), in: Circle())
            Text(profile.name)
                .font(.headline)
                .lineLimit(1)
            Text("\(profile.ageBand.rawValue) años")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
