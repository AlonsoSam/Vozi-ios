import SwiftUI

/// Pantalla de inicio + consentimiento del adulto.
struct PermissionsView: View {
    @Binding var authorized: Bool?
    let denied: Bool
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("VOZI · Validación de voz")
                .font(.title2.bold())

            Text("Fase 0 — Spike de Speech-to-Text")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Herramienta operada por un adulto para probar el reconocimiento de voz en niños de 4 a 7 años. El audio se procesa en el dispositivo; VOZI no almacena ni sube el audio, solo el texto aproximado y métricas.")
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
