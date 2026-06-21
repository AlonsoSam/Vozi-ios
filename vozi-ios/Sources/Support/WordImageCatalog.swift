import SwiftUI
import UIKit

/// Resuelve la imagen estática de apoyo de una palabra (spec §10).
///
/// Las imágenes viven en `Resources/Media.xcassets` como image sets nombrados
/// `word_<palabra_sin_tildes>` (ej. "lápiz" → "word_lapiz"). El catálogo puede
/// estar incompleto: si el asset no existe, `image(forKey:)` devuelve `nil` y la
/// UI muestra un placeholder. Espejo de `AvatarCatalog`: la clave es estable y se
/// guarda/usa como `ContentItem.imageKey`.
enum WordImageCatalog {

    /// Deriva la clave estable de asset para una palabra: minúsculas, sin tildes,
    /// espacios → guion bajo, prefijo "word_". Ej: "lápiz" → "word_lapiz".
    static func imageKey(for word: String) -> String {
        let folded = word.folding(options: .diacriticInsensitive,
                                  locale: Locale(identifier: "es"))
        let normalized = folded
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        return "word_\(normalized)"
    }

    /// Imagen del asset si existe en el bundle; si no, `nil` (la UI usa placeholder).
    static func image(forKey key: String?) -> Image? {
        guard let key, UIImage(named: key) != nil else { return nil }
        return Image(key)
    }
}

/// Imagen estática de apoyo de una palabra, en una card consistente (spec §10/§11).
///
/// Solo se renderiza si el ítem tiene `imageKey` (las palabras lo llevan; sílabas
/// no). Si la clave existe pero el asset aún no está empaquetado, muestra un
/// placeholder amable en vez de un hueco. Altura fija para no colapsar entre
/// `Spacer()` y sin deformar la imagen (`scaledToFit`).
struct WordImageView: View {
    let imageKey: String?
    var height: CGFloat = 150

    var body: some View {
        if let imageKey {
            card {
                if let image = WordImageCatalog.image(forKey: imageKey) {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 200)
            .frame(height: height)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .accessibilityHidden(true)
    }
}
