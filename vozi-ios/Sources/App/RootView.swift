import SwiftUI

/// Compuerta de permisos: sin micrófono + reconocimiento de voz no se puede validar.
struct RootView: View {
    @State private var authorized: Bool?

    var body: some View {
        switch authorized {
        case .some(true):
            SpeechSpikeView()
        case .some(false):
            PermissionsView(authorized: $authorized, denied: true)
        case .none:
            PermissionsView(authorized: $authorized, denied: false)
        }
    }
}
