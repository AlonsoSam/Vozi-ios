import SwiftUI
import SwiftData

/// Home del niño: grid de los 9 fonemas/grupos del MVP con su estado (disponible /
/// bloqueado / completado). Tocar un fonema disponible entra directo a la práctica
/// de Palabras. Texto mínimo y botones grandes (spec §11).
struct ChildHomeView: View {
    let profile: ChildProfile

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    /// Progreso de fonemas/grupos ordenado pedagógicamente (R, RR, S, L, TR, PR, PL, BR, BL).
    private var orderedProgress: [PhonemeProgress] {
        profile.phonemeProgress.sorted { ($0.phoneme?.order ?? .max) < ($1.phoneme?.order ?? .max) }
    }

    /// Personajes ya desbloqueados (para el resumen del encabezado).
    private var unlockedSkins: Int {
        SkinCatalog.all.filter { SkinCatalog.isUnlocked($0, for: profile) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                rewardsHeader

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(orderedProgress) { progress in
                        tile(for: progress)
                    }
                }
            }
            .padding(20)
        }
        .background(VoziTheme.background.ignoresSafeArea())
        .navigationTitle("¡Hola, \(profile.name)!")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: StageProgress.self) { stageProgress in
            ExerciseView(stageProgress: stageProgress)
        }
    }

    /// Acceso a "Mis recompensas": resume puntos y personajes, y empuja `RewardsView`.
    private var rewardsHeader: some View {
        NavigationLink {
            RewardsView(profile: profile)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(colors: [VoziTheme.sunshine, VoziTheme.peach],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mis recompensas")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("\(profile.points) puntos · \(unlockedSkins)/\(SkinCatalog.all.count) personajes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .voziCard(cornerRadius: 22)
        }
        .buttonStyle(VoziPressableStyle())
        .accessibilityLabel("Mis recompensas. \(profile.points) puntos, \(unlockedSkins) de \(SkinCatalog.all.count) personajes.")
    }

    /// Etapa de Palabras del fonema (flujo MVP: entra directo aquí).
    private func wordsStage(_ progress: PhonemeProgress) -> StageProgress? {
        progress.stages.first { $0.stage == .palabras }
    }

    @ViewBuilder
    private func tile(for progress: PhonemeProgress) -> some View {
        // No bloqueado (o modo desarrollador): entra directo a la práctica de
        // palabras. El progreso real no se altera; solo se evita el candado.
        let unlocked = progress.status != .locked || DeveloperSettings.isDeveloperModeEnabled
        if unlocked, let stage = wordsStage(progress) {
            NavigationLink(value: stage) {
                PhonemeTile(progress: progress,
                            forceUnlocked: DeveloperSettings.isDeveloperModeEnabled)
            }
            .buttonStyle(VoziPressableStyle())
        } else {
            PhonemeTile(progress: progress)
        }
    }
}

/// Tarjeta grande y colorida de un fonema con icono y estado.
private struct PhonemeTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: PhonemeProgress
    /// En modo desarrollador se muestra desbloqueado aunque el estado sea locked.
    var forceUnlocked: Bool = false

    @State private var appeared = false

    var body: some View {
        let phoneme = progress.phoneme
        let locked = progress.status == .locked && !forceUnlocked
        let completed = progress.status == .completed
        let color = phoneme.map(VoziTheme.color(for:)) ?? VoziTheme.sky

        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: locked
                                ? [Color(.systemGray3), Color(.systemGray4)]
                                : [color, color.opacity(0.72)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: (locked ? Color.black.opacity(0.12) : color.opacity(0.45)),
                            radius: 9, x: 0, y: 5)

                Image(systemName: phoneme?.iconSystemName ?? "questionmark")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .bottomTrailing) { statusBadge(locked: locked, completed: completed) }

            Text(phoneme?.displayName ?? "—")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(locked ? Color.secondary : color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .voziCard(cornerRadius: 26)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? (locked ? 0.7 : 1) : 0)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            }
        }
        .accessibilityLabel(accessibilityText(phoneme: phoneme, locked: locked, completed: completed))
    }

    @ViewBuilder
    private func statusBadge(locked: Bool, completed: Bool) -> some View {
        if locked {
            badgeIcon("lock.fill", .secondary)
        } else if completed {
            badgeIcon("checkmark.circle.fill", VoziTheme.success)
        }
    }

    private func badgeIcon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
            .background(Circle().fill(.background))
    }

    private func accessibilityText(phoneme: Phoneme?, locked: Bool, completed: Bool) -> String {
        let name = phoneme?.displayName ?? ""
        if locked { return "Fonema \(name), bloqueado" }
        if completed { return "Fonema \(name), completado" }
        return "Fonema \(name), disponible"
    }
}
