import SwiftUI
import SwiftData

/// Home del niño: grid de los 9 fonemas/grupos del MVP con su estado (disponible /
/// bloqueado / completado). Tocar un fonema disponible entra directo a la práctica
/// de Palabras. Texto mínimo y botones grandes (spec §11).
struct ChildHomeView: View {
    let profile: ChildProfile
    @EnvironmentObject private var premium: PremiumStore

    /// Se muestra la pantalla de planes al tocar un fonema bloqueado por Premium.
    @State private var showPremium = false

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
        .voziBackground()
        .navigationTitle("¡Hola, \(profile.name)!")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: StageProgress.self) { stageProgress in
            ExerciseView(stageProgress: stageProgress)
        }
        .sheet(isPresented: $showPremium) {
            PremiumView()
        }
    }

    /// Acceso a "Mis recompensas": resume puntos y personajes, y empuja `RewardsView`.
    private var rewardsHeader: some View {
        NavigationLink {
            RewardsView(profile: profile)
        } label: {
            HStack(spacing: VoziTheme.Space.md) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(VoziTheme.premiumGradient, in: Circle())
                    .shadow(color: VoziTheme.sunshine.opacity(0.4), radius: 7, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mis recompensas")
                        .font(.vozi(.headline, weight: .bold))
                        .foregroundStyle(VoziTheme.ink)
                    HStack(spacing: 8) {
                        Label("\(profile.points)", systemImage: "star.fill")
                            .foregroundStyle(VoziTheme.sunshine)
                        Label("\(unlockedSkins)/\(SkinCatalog.all.count)", systemImage: "sparkles")
                            .foregroundStyle(VoziTheme.mint)
                    }
                    .font(.vozi(.subheadline, weight: .semibold))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(VoziTheme.inkSoft)
            }
            .padding(VoziTheme.Space.md)
            .voziCard()
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
        // Gate Premium (Fase 6): en modo gratuito solo R está disponible; los demás
        // fonemas/grupos se ven bloqueados por Premium. El modo desarrollador y el
        // Premium activo ignoran este bloqueo. NO altera el progreso ni la evaluación.
        if !premium.canAccess(progress.phoneme) {
            Button { showPremium = true } label: {
                PhonemeTile(progress: progress, premiumLocked: true)
            }
            .buttonStyle(VoziPressableStyle())
        } else {
            // Accesible por Premium/gratuito/dev: aplica el desbloqueo normal por
            // progreso. El modo desarrollador evita el candado de progreso en la UI.
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
}

/// Tarjeta grande y colorida de un fonema con icono y estado.
private struct PhonemeTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: PhonemeProgress
    /// En modo desarrollador se muestra desbloqueado aunque el estado sea locked.
    var forceUnlocked: Bool = false
    /// Bloqueado por Premium (Fase 6): se ve distinto al candado de progreso
    /// (corona dorada + etiqueta "Premium" en vez de candado gris).
    var premiumLocked: Bool = false

    @State private var appeared = false

    var body: some View {
        let phoneme = progress.phoneme
        let locked = progress.status == .locked && !forceUnlocked && !premiumLocked
        let completed = progress.status == .completed && !premiumLocked
        let dimmed = locked || premiumLocked
        let color = phoneme.map(VoziTheme.color(for:)) ?? VoziTheme.sky

        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: premiumLocked
                                ? [VoziTheme.sunshine, VoziTheme.peach]
                                : (locked
                                    ? [Color(.systemGray3), Color(.systemGray4)]
                                    : [color, color.opacity(0.72)]),
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: (dimmed ? Color.black.opacity(0.12) : color.opacity(0.45)),
                            radius: 9, x: 0, y: 5)

                Image(systemName: phoneme?.iconSystemName ?? "questionmark")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(premiumLocked ? 0.85 : 1)
            }
            .overlay(alignment: .bottomTrailing) {
                statusBadge(locked: locked, completed: completed, premiumLocked: premiumLocked)
            }

            Text(phoneme?.displayName ?? "—")
                .font(.vozi(.title2, weight: .bold))
                .foregroundStyle(premiumLocked ? VoziTheme.peach : (locked ? VoziTheme.inkSoft : color))

            // Etiqueta de estado bajo el nombre, unificada con el resto de la app.
            if premiumLocked {
                VoziStatusChip(status: .lockedPremium)
            } else if completed {
                VoziStatusChip(status: .completed)
            } else if locked {
                VoziStatusChip(status: .lockedProgress)
            } else {
                VoziStatusChip(status: .available)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .voziCard(cornerRadius: 26)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? (dimmed ? 0.7 : 1) : 0)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            }
        }
        .accessibilityLabel(accessibilityText(phoneme: phoneme, locked: locked,
                                              completed: completed, premiumLocked: premiumLocked))
    }

    @ViewBuilder
    private func statusBadge(locked: Bool, completed: Bool, premiumLocked: Bool) -> some View {
        if premiumLocked {
            VoziIconBadge(symbol: "crown.fill", color: VoziTheme.sunshine)
        } else if locked {
            VoziIconBadge(symbol: "lock.fill", color: VoziTheme.neutral)
        } else if completed {
            VoziIconBadge(symbol: "checkmark.circle.fill", color: VoziTheme.success)
        }
    }

    private func accessibilityText(phoneme: Phoneme?, locked: Bool,
                                   completed: Bool, premiumLocked: Bool) -> String {
        let name = phoneme?.displayName ?? ""
        if premiumLocked { return "Fonema \(name), bloqueado por Premium" }
        if locked { return "Fonema \(name), bloqueado" }
        if completed { return "Fonema \(name), completado" }
        return "Fonema \(name), disponible"
    }
}
