import SwiftUI

/// Compuerta de "zona de adultos" con PIN local simple (decisión de Fase 1).
/// El PIN se guarda en UserDefaults (no es seguridad fuerte; evita que el niño
/// entre por accidente). La Auth real de padres con Supabase llega en una
/// sub-fase posterior; aquí NO se integra backend.
struct ParentGateView<Content: View>: View {
    @AppStorage("vozi.parentPIN") private var storedPIN = ""
    @State private var entry = ""
    @State private var confirm = ""
    @State private var unlocked = false
    @State private var error: String?

    @ViewBuilder let content: () -> Content

    var body: some View {
        if unlocked {
            content()
        } else if storedPIN.isEmpty {
            setupView
        } else {
            entryView
        }
    }

    private var setupView: some View {
        gateLayout(
            title: "Crear PIN de adulto",
            subtitle: "Define un PIN de 4 dígitos para proteger la zona de adultos."
        ) {
            field("PIN nuevo", text: $entry)
            field("Repetir PIN", text: $confirm)
            Button("Guardar PIN") { savePIN() }
                .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.brand))
                .disabled(entry.count < 4)
                .opacity(entry.count < 4 ? 0.6 : 1)
        }
    }

    private var entryView: some View {
        gateLayout(
            title: "Zona de adultos",
            subtitle: "Ingresa tu PIN para ver el progreso."
        ) {
            field("PIN", text: $entry)
            Button("Entrar") { checkPIN() }
                .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.brand))
                .disabled(entry.isEmpty)
                .opacity(entry.isEmpty ? 0.6 : 1)
        }
    }

    private func gateLayout<Fields: View>(
        title: String,
        subtitle: String,
        @ViewBuilder fields: () -> Fields
    ) -> some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: VoziTheme.Space.lg) {
                VoziHero(symbol: "lock.shield.fill", title: title, subtitle: subtitle,
                         color: VoziTheme.lavender)

                VStack(spacing: VoziTheme.Space.md) {
                    fields()
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.vozi(.footnote, weight: .semibold))
                            .foregroundStyle(VoziTheme.coral)
                    }
                }
                .padding(VoziTheme.Space.lg)
                .voziCard()
            }
            .frame(maxWidth: 360)
            .padding(VoziTheme.Space.xl)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .voziBackground()
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .font(.vozi(.title3, weight: .semibold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .padding(.vertical, 14)
            .background(VoziTheme.brand.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: VoziTheme.Radius.sm, style: .continuous))
    }

    private func savePIN() {
        guard entry.count >= 4 else { error = "El PIN debe tener al menos 4 dígitos."; return }
        guard entry == confirm else { error = "Los PIN no coinciden."; return }
        storedPIN = entry
        error = nil
        entry = ""; confirm = ""
        unlocked = true
    }

    private func checkPIN() {
        if entry == storedPIN {
            error = nil
            entry = ""
            unlocked = true
        } else {
            error = "PIN incorrecto."
            entry = ""
        }
    }
}
