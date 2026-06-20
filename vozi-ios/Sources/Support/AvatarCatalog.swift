import SwiftUI

/// Avatares placeholder para los perfiles de niño (spec §11: iconografía clara).
/// Son SF Symbols por ahora; se reemplazarán por ilustración/mascota propia en Fase 4.
/// `key` es el valor estable que se guarda en `ChildProfile.avatarKey`.
struct AvatarOption: Identifiable, Hashable {
    let key: String
    let symbol: String
    let tint: Color
    var id: String { key }
}

enum AvatarCatalog {
    static let all: [AvatarOption] = [
        AvatarOption(key: "fox",    symbol: "hare.fill",       tint: .orange),
        AvatarOption(key: "bear",   symbol: "pawprint.fill",   tint: .brown),
        AvatarOption(key: "cat",    symbol: "cat.fill",        tint: .pink),
        AvatarOption(key: "owl",    symbol: "bird.fill",       tint: .purple),
        AvatarOption(key: "fish",   symbol: "fish.fill",       tint: .teal),
        AvatarOption(key: "star",   symbol: "star.fill",       tint: .yellow),
    ]

    static let `default` = "fox"

    static func option(for key: String) -> AvatarOption {
        all.first { $0.key == key } ?? all[0]
    }
}
