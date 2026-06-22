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

    /// Avatar elegido (para la vista previa en vivo del encabezado).
    private var selectedAvatar: AvatarOption { AvatarCatalog.option(for: avatarKey) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VoziTheme.Space.lg) {
                    // Vista previa en vivo del perfil que se está creando/editando.
                    VStack(spacing: VoziTheme.Space.sm) {
                        VoziHeroIcon(symbol: selectedAvatar.symbol, color: selectedAvatar.tint, size: 96)
                        Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Nuevo peque" : name)
                            .font(.vozi(.title2, weight: .bold))
                            .foregroundStyle(VoziTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("\(ageBand.rawValue) años")
                            .font(.vozi(.subheadline, weight: .semibold))
                            .foregroundStyle(selectedAvatar.tint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, VoziTheme.Space.sm)

                    VoziSection(title: "Nombre", symbol: "textformat", color: VoziTheme.brand) {
                        TextField("Nombre del niño", text: $name)
                            .textInputAutocapitalization(.words)
                            .font(.vozi(.body, weight: .medium))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(VoziTheme.brand.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: VoziTheme.Radius.sm, style: .continuous))
                    }

                    VoziSection(title: "Edad", symbol: "birthday.cake.fill", color: VoziTheme.peach) {
                        Picker("Edad", selection: $ageBand) {
                            ForEach(AgeBand.allCases) { band in
                                Text("\(band.rawValue) años").tag(band)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VoziSection(title: "Avatar", symbol: "face.smiling.fill", color: VoziTheme.bubblegum) {
                        LazyVGrid(columns: columns, spacing: VoziTheme.Space.md) {
                            ForEach(AvatarCatalog.all) { option in
                                avatarCell(option)
                            }
                        }
                    }
                }
                .padding(VoziTheme.Space.lg)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .voziBackground()
            .navigationTitle(isEditing ? "Editar perfil" : "Nuevo perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save).disabled(!canSave).bold()
                }
            }
        }
    }

    private func avatarCell(_ option: AvatarOption) -> some View {
        let selected = option.key == avatarKey
        return Image(systemName: option.symbol)
            .font(.system(size: 30))
            .foregroundStyle(selected ? .white : option.tint)
            .frame(width: 64, height: 64)
            .background(
                selected ? AnyShapeStyle(VoziTheme.gradient(option.tint))
                         : AnyShapeStyle(option.tint.opacity(0.15)),
                in: Circle()
            )
            .overlay(Circle().strokeBorder(option.tint, lineWidth: selected ? 3 : 0))
            .shadow(color: selected ? option.tint.opacity(0.4) : .clear, radius: 6, x: 0, y: 3)
            .accessibilityLabel(option.key)
            .onTapGesture { avatarKey = option.key }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let profile {
            profile.name = trimmed
            profile.ageBandRaw = ageBand.rawValue
            profile.avatarKey = avatarKey
            profile.markDirty()   // Fase 7.3: edición → pendiente de sincronizar.
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
