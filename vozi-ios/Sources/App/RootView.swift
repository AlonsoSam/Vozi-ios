import SwiftUI

/// Compuerta de permisos: sin micrófono + reconocimiento de voz no se puede usar.
struct RootView: View {
    @State private var authorized: Bool?

    var body: some View {
        switch authorized {
        case .some(true):
            TabView {
                // Fase 1: selección/gestión de perfiles y práctica del niño.
                ProfilesView()
                    .tabItem {
                        Label("Perfiles", systemImage: "person.2.fill")
                    }

                // Fase 1: panel de padres (zona de adultos, protegida por PIN).
                ParentGateView {
                    ParentPanelView()
                }
                .tabItem {
                    Label("Adultos", systemImage: "lock.shield.fill")
                }
            }
        case .some(false):
            PermissionsView(authorized: $authorized, denied: true)
        case .none:
            PermissionsView(authorized: $authorized, denied: false)
        }
    }
}
