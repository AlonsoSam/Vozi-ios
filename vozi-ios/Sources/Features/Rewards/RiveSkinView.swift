import SwiftUI
import RiveRuntime

/// Render del personaje en la vitrina de "Mis recompensas" (Fase 4B). Llena el
/// 100% del área que le da la card: si la skin tiene `rivFileName` Y el `.riv`
/// está empaquetado, muestra la animación Rive (con su fondo, en modo `.cover`);
/// en cualquier otro caso cae a un panel placeholder (color + SF Symbol).
///
/// Seguridad: `RiveViewModel(fileName:)` hace fatalError si el archivo no existe,
/// por eso se verifica antes en el bundle. Solo se usa para skins DESBLOQUEADAS.
struct RiveSkinView: View {
    let skin: Skin

    var body: some View {
        if let name = skin.rivFileName, Self.rivExists(name) {
            RiveFill(fileName: name)
        } else {
            // Fallback: panel a color (mismo look de vitrina, sin recorte pequeño).
            SkinPanel(symbol: skin.symbol, colors: [skin.color, skin.color.opacity(0.75)])
        }
    }

    /// ¿El `.riv` está realmente empaquetado? Evita el fatalError de Rive.
    static func rivExists(_ name: String) -> Bool {
        Bundle.main.url(forResource: name, withExtension: "riv") != nil
    }
}

/// Animación Rive que llena el área disponible. Se instancia SOLO cuando el
/// `.riv` existe, así que construir el `RiveViewModel` es seguro. Usa `.cover`
/// para que el fondo del artboard cubra toda la vitrina (sin barras).
private struct RiveFill: View {
    @StateObject private var rive: RiveViewModel

    init(fileName: String) {
        _rive = StateObject(wrappedValue: RiveViewModel(fileName: fileName, fit: .cover))
    }

    var body: some View {
        rive.view()
    }
}

/// Panel estático que llena el área: degradado + un SF Symbol grande centrado.
/// Placeholder de vitrina (desbloqueado a color, bloqueado en gris con candado).
struct SkinPanel: View {
    // `RiveRuntime` también exporta `Color`, por eso se cualifica `SwiftUI.Color`
    // en este archivo (el único que importa Rive).
    let symbol: String
    let colors: [SwiftUI.Color]

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(SwiftUI.Color.white.opacity(0.95))
        }
    }
}
