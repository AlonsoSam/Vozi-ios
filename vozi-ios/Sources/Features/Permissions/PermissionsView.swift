import SwiftUI

/// Pantalla de inicio + consentimiento del adulto (spec §6, §7).
/// El adulto autoriza micrófono y reconocimiento de voz antes de practicar.
struct PermissionsView: View {
    @Binding var authorized: Bool?
    let denied: Bool
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("VOZI")
                .font(.largeTitle.bold())

            Text("Práctica y refuerzo de pronunciación")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Experiencia educativa para niños de 4 a 7 años. La práctica usa el micrófono para apoyar el refuerzo de fonemas. El audio se procesa en el dispositivo; VOZI no almacena ni sube el audio, solo el texto aproximado y el progreso.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if denied {
                Text("Permiso denegado. Actívalo en Ajustes para continuar.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    requesting = true
                    authorized = await SpeechAuthorization.requestAll()
                    requesting = false
                }
            } label: {
                Text(requesting ? "Solicitando…" : "Conceder micrófono y voz")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(requesting)
        }
        .padding(32)
    }
}
