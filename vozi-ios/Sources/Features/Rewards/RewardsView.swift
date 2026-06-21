import SwiftUI

/// Sección "Mis recompensas / Mi progreso" (Fase 4). Solo lectura: muestra los
/// puntos del niño y, por cada fonema/grupo, su personaje coleccionable con el
/// estado de desbloqueo y el requisito. No altera el progreso ni la evaluación.
struct RewardsView: View {
    let profile: ChildProfile

    // Una sola columna: cada personaje se ve en una card grande tipo vitrina.
    private let columns = [GridItem(.flexible())]

    /// Skins ordenadas pedagógicamente (R, RR, S, L, TR, PR, PL, BR, BL).
    private var skins: [Skin] {
        SkinCatalog.all.sorted {
            (Phoneme(rawValue: $0.phonemeCode)?.order ?? .max)
                < (Phoneme(rawValue: $1.phonemeCode)?.order ?? .max)
        }
    }

    private var unlockedCount: Int {
        skins.filter { SkinCatalog.isUnlocked($0, for: profile) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    Text("Personajes")
                        .font(.system(.title3, design: .rounded).bold())
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(skins) { skin in
                            SkinCard(
                                skin: skin,
                                completions: profile.completionCount(forCode: skin.phonemeCode)
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(VoziTheme.background.ignoresSafeArea())
        .navigationTitle("Mis recompensas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let avatar = AvatarCatalog.option(for: profile.avatarKey)
        return VStack(spacing: 12) {
            Image(systemName: avatar.symbol)
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(
                    LinearGradient(colors: [avatar.tint, avatar.tint.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: avatar.tint.opacity(0.4), radius: 8, x: 0, y: 4)

            Text(profile.name)
                .font(.system(.title2, design: .rounded).bold())

            HStack(spacing: 16) {
                statPill("star.fill", "\(profile.points) puntos", VoziTheme.sunshine)
                statPill("trophy.fill", "\(unlockedCount)/\(skins.count)", VoziTheme.mint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .voziCard(cornerRadius: 26)
    }

    private func statPill(_ symbol: String, _ text: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(color.opacity(0.16), in: Capsule())
    }
}

/// Vitrina de un personaje (Fase 4B): card grande de una columna. La parte
/// superior es el escenario donde el Rive (o el placeholder) ocupa el 100% del
/// área, con borde y esquinas redondeadas; debajo, el nombre y el estado de
/// desbloqueo. No altera la lógica de puntos/desbloqueo, solo presenta el estado.
private struct SkinCard: View {
    let skin: Skin
    let completions: Int

    private var unlocked: Bool { completions >= skin.requiredCompletions }
    private var displayName: String { Phoneme(rawValue: skin.phonemeCode)?.displayName ?? skin.phonemeCode }
    private var clampedProgress: Double {
        guard skin.requiredCompletions > 0 else { return 1 }
        return min(Double(completions) / Double(skin.requiredCompletions), 1)
    }

    private let stageHeight: CGFloat = 240
    private let corner: CGFloat = 26

    var body: some View {
        VStack(spacing: 14) {
            stage
            info
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// Escenario/vitrina: el personaje (Rive o placeholder) llena todo el área,
    /// recortado a la card. Desbloqueado se ve normal; bloqueado se ve igual pero
    /// con blur suave + velo + candado, para que el niño vea qué puede conseguir.
    private var stage: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RiveSkinView(skin: skin)
                    .blur(radius: unlocked ? 0 : 5)

                if !unlocked {
                    // Velo suave (asegura el look bloqueado aunque el blur no afecte
                    // a la capa Metal de Rive) + candado, sin ocultar al personaje.
                    Color(.systemBackground).opacity(0.22)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: stageHeight)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(VoziTheme.success)
                    .background(Circle().fill(.background))
                    .padding(12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(unlocked ? skin.color : Color(.systemGray3), lineWidth: 3)
        )
        .shadow(color: (unlocked ? skin.color : .black).opacity(0.22), radius: 12, x: 0, y: 6)
    }

    /// Nombre + estado de desbloqueo (debajo de la vitrina).
    private var info: some View {
        VStack(spacing: 8) {
            Text(skin.name)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if unlocked {
                Label("¡Desbloqueado!", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VoziTheme.success)
            } else {
                VStack(spacing: 6) {
                    ProgressView(value: clampedProgress)
                        .tint(skin.color)
                    Text("Completa \(displayName) \(skin.requiredCompletions) veces · \(completions)/\(skin.requiredCompletions)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 4)
    }

    private var accessibilityText: String {
        if unlocked {
            return "\(skin.name), desbloqueado"
        }
        return "\(skin.name), bloqueado. Completa \(displayName) \(skin.requiredCompletions) veces. Llevas \(completions)."
    }
}
