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
            SecureField("PIN nuevo", text: $entry)
            SecureField("Repetir PIN", text: $confirm)
            Button("Guardar PIN") { savePIN() }
                .buttonStyle(.borderedProminent)
                .disabled(entry.count < 4)
        }
    }

    private var entryView: some View {
        gateLayout(
            title: "Zona de adultos",
            subtitle: "Ingresa tu PIN para ver el progreso."
        ) {
            SecureField("PIN", text: $entry)
            Button("Entrar") { checkPIN() }
                .buttonStyle(.borderedProminent)
                .disabled(entry.isEmpty)
        }
    }

    private func gateLayout<Fields: View>(
        title: String,
        subtitle: String,
        @ViewBuilder fields: () -> Fields
    ) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title).font(.title2.bold())
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                fields()
            }
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)
            .frame(maxWidth: 320)

            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(32)
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
