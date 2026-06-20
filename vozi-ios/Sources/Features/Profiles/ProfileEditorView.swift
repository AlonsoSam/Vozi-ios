import SwiftUI
import SwiftData

/// Editor de perfil de niño (crear o editar). Operado por el adulto (spec §5).
/// Al crear, usa `ProgressFactory` para sembrar el árbol de progreso inicial.
struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// nil = crear un perfil nuevo; no-nil = editar el existente.
    let profile: ChildProfile?

    @State private var name: String
    @State private var ageBand: AgeBand
    @State private var avatarKey: String

    init(profile: ChildProfile? = nil) {
        self.profile = profile
        _name = State(initialValue: profile?.name ?? "")
        _ageBand = State(initialValue: profile?.ageBand ?? .young)
        _avatarKey = State(initialValue: profile?.avatarKey ?? AvatarCatalog.default)
    }

    private var isEditing: Bool { profile != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 16)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre del niño", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Edad") {
                    Picker("Edad", selection: $ageBand) {
                        ForEach(AgeBand.allCases) { band in
                            Text("\(band.rawValue) años").tag(band)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Avatar") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AvatarCatalog.all) { option in
                            avatarCell(option)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "Editar perfil" : "Nuevo perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func avatarCell(_ option: AvatarOption) -> some View {
        let selected = option.key == avatarKey
        return Image(systemName: option.symbol)
            .font(.system(size: 30))
            .foregroundStyle(option.tint)
            .frame(width: 64, height: 64)
            .background(option.tint.opacity(0.15), in: Circle())
            .overlay(Circle().strokeBorder(option.tint, lineWidth: selected ? 3 : 0))
            .accessibilityLabel(option.key)
            .onTapGesture { avatarKey = option.key }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let profile {
            profile.name = trimmed
            profile.ageBandRaw = ageBand.rawValue
            profile.avatarKey = avatarKey
        } else {
            ProgressFactory.makeProfile(
                name: trimmed,
                ageBand: ageBand,
                avatarKey: avatarKey,
                in: context
            )
        }
        try? context.save()
        dismiss()
    }
}
