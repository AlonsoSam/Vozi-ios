import SwiftUI

/// Pantalla de inicio + consentimiento del adulto (spec §6, §7).
/// El adulto autoriza micrófono y reconocimiento de voz antes de practicar.
struct PermissionsView: View {
    @Binding var authorized: Bool?
    let denied: Bool
    @State private var requesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: VoziTheme.Space.xl) {
                Spacer(minLength: VoziTheme.Space.lg)

                // Marca: logotipo hero + nombre + tagline.
                VStack(spacing: VoziTheme.Space.md) {
                    VoziHeroIcon(symbol: "waveform", color: VoziTheme.brand, size: 116)
                    Text("VOZI")
                        .font(.vozi(size: 46, weight: .heavy))
                        .foregroundStyle(VoziTheme.ink)
                    Text("Práctica y refuerzo de pronunciación")
                        .font(.vozi(.headline))
                        .foregroundStyle(VoziTheme.inkSoft)
                        .multilineTextAlignment(.center)
                }

                // Tarjeta de consentimiento, clara para el adulto.
                VStack(spacing: VoziTheme.Space.md) {
                    infoRow("figure.and.child.holding.hands",
                            "Para peques de 4 a 7 años",
                            "Una experiencia educativa para practicar fonemas jugando.")
                    Divider()
                    infoRow("mic.fill",
                            "Usa el micrófono",
                            "La práctica escucha al niño para apoyar el refuerzo de sonidos.")
                    Divider()
                    infoRow("lock.shield.fill",
                            "Privacidad primero",
                            "El audio se procesa en el dispositivo. VOZI no guarda ni sube audio: solo texto aproximado y progreso.")
                }
                .padding(VoziTheme.Space.lg)
                .voziCard()

                if denied {
                    Label("Permiso denegado. Actívalo en Ajustes para continuar.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.vozi(.footnote, weight: .semibold))
                        .foregroundStyle(VoziTheme.coral)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        requesting = true
                        authorized = await SpeechAuthorization.requestAll()
                        requesting = false
                    }
                } label: {
                    Label(requesting ? "Solicitando…" : "Conceder micrófono y voz",
                          systemImage: requesting ? "hourglass" : "checkmark.circle.fill")
                }
                .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.mint))
                .disabled(requesting)

                Spacer(minLength: VoziTheme.Space.md)
            }
            .padding(VoziTheme.Space.xl)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .voziBackground()
    }

    private func infoRow(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: VoziTheme.Space.md) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(VoziTheme.brand)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.vozi(.subheadline, weight: .bold))
                    .foregroundStyle(VoziTheme.ink)
                Text(subtitle)
                    .font(.vozi(.footnote))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
