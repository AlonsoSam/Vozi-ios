import SwiftUI

/// Pantalla de planes de **VOZI Premium (Fase 6 — pago simulado)**.
///
/// Compara el plan Gratis (solo el grupo R) con el plan Premium (todos los
/// fonemas/grupos). Es una **simulación para sustentación**: no hay cobro real,
/// ni Culqi, ni StoreKit. El botón solo cambia un flag local en `PremiumStore`.
struct PremiumView: View {
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    private let freeFeatures = [
        "Practica el grupo R",
        "Escuchar y Hablar con feedback",
        "Puntos y recompensas",
    ]
    private let premiumFeatures = [
        "Todos los fonemas y grupos (9)",
        "Sin candados Premium",
        "Más palabras para practicar",
        "Todos los personajes por desbloquear",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    if premium.isPremium {
                        activeBanner
                    }

                    planCard(
                        title: "Gratis",
                        subtitle: "Para empezar a practicar",
                        icon: "gift.fill",
                        tint: VoziTheme.sky,
                        features: freeFeatures,
                        highlighted: !premium.isPremium
                    )

                    planCard(
                        title: "Premium",
                        subtitle: "Desbloquea toda la aventura",
                        icon: "crown.fill",
                        tint: VoziTheme.sunshine,
                        features: premiumFeatures,
                        highlighted: premium.isPremium
                    )

                    actions

                    sourceCaption

                    disclaimer
                }
                .padding(20)
            }
            .voziBackground()
            .navigationTitle("VOZI Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            VoziHeroIcon(symbol: "crown.fill",
                         gradient: VoziTheme.premiumGradient,
                         shadowColor: VoziTheme.sunshine, size: 92)
            Text("Desbloquea todos los fonemas")
                .font(.vozi(.title2, weight: .bold))
                .foregroundStyle(VoziTheme.ink)
                .multilineTextAlignment(.center)
            Text("Con Premium tu peque practica todos los grupos de sonidos, no solo la R.")
                .font(.vozi(.subheadline))
                .foregroundStyle(VoziTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var activeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Premium activo")
                    .font(.vozi(.headline, weight: .bold)).foregroundStyle(.white)
                Text("Todos los fonemas están disponibles.")
                    .font(.vozi(.subheadline)).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(16)
        .background(VoziTheme.gradient(VoziTheme.success),
                    in: RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous))
        .shadow(color: VoziTheme.success.opacity(0.35), radius: 10, x: 0, y: 6)
    }

    private func planCard(title: String,
                          subtitle: String,
                          icon: String,
                          tint: Color,
                          features: [String],
                          highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.vozi(.title3, weight: .bold)).foregroundStyle(VoziTheme.ink)
                    Text(subtitle).font(.vozi(.subheadline)).foregroundStyle(VoziTheme.inkSoft)
                }
                Spacer(minLength: 0)
                if highlighted {
                    Text("Tu plan")
                        .font(.vozi(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(tint, in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(tint)
                        Text(feature).font(.vozi(.callout)).foregroundStyle(VoziTheme.ink)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .voziCard(cornerRadius: VoziTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: VoziTheme.Radius.lg, style: .continuous)
                .strokeBorder(highlighted ? tint : .clear, lineWidth: 3)
        )
    }

    @ViewBuilder
    private var actions: some View {
        if premium.isPremium {
            Button {
                premium.deactivate()
            } label: {
                Label("Desactivar Premium demo", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(VoziSecondaryButtonStyle(tint: VoziTheme.coral))
        } else {
            Button {
                premium.activate()
            } label: {
                Label("Activar Premium demo", systemImage: "crown.fill")
            }
            .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.sunshine))
        }
    }

    /// Origen del estado Premium: per-cuenta (con sesión) o demo local (sin sesión).
    private var sourceCaption: some View {
        Label(premium.source == .account
              ? "Premium ligado a tu cuenta: el estado se sincroniza entre tus dispositivos."
              : "Premium demo local en este dispositivo. Inicia sesión de adulto para ligarlo a tu cuenta.",
              systemImage: premium.source == .account ? "person.icloud.fill" : "iphone")
            .font(.vozi(.footnote))
            .foregroundStyle(premium.source == .account ? VoziTheme.success : VoziTheme.inkSoft)
            .multilineTextAlignment(.center)
    }

    private var disclaimer: some View {
        Label("Demostración para sustentación. Premium es una simulación: no hay cobro real ni procesamiento de pagos.",
              systemImage: "info.circle")
            .font(.vozi(.footnote))
            .foregroundStyle(VoziTheme.inkSoft)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}
