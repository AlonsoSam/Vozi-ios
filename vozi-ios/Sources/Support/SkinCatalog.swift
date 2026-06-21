import SwiftUI

/// Skin/personaje coleccionable de gamificación (Fase 4). Cada uno está atado a
/// un fonema/grupo y se desbloquea al completar su lista de palabras suficientes
/// veces. Por ahora se representa con un placeholder (SF Symbol + color del
/// fonema); `rivFileName` queda preparado para sustituirlo por una animación Rive
/// en un sub-bloque posterior, sin refactor.
struct Skin: Identifiable, Hashable {
    let id: String                 // estable, ej. "skin_rr"
    let name: String               // nombre del personaje, mostrado al niño
    let phonemeCode: String        // fonema/grupo asociado ("R", "RR", ...)
    let requiredCompletions: Int   // completaciones necesarias para desbloquear
    let symbol: String             // placeholder SF Symbol
    let rivFileName: String?       // futuro: nombre del .riv (nil por ahora)

    /// Color de identidad del fonema/grupo (de `VoziTheme`). Solo presentación.
    var color: Color { VoziTheme.color(forCode: phonemeCode) }
}

/// Catálogo estático de skins/personajes del MVP: uno por fonema/grupo.
///
/// Regla de desbloqueo (Fase 4): completar el fonema/grupo `requiredCompletions`
/// veces. Normal = 3; **RR = 1** como prueba rápida del flujo de desbloqueo. El
/// estado desbloqueado NO se persiste: se deriva del `completionCount` del perfil,
/// evitando sincronizar un booleano.
enum SkinCatalog {

    /// Requisito normal de completaciones.
    static let normalRequirement = 3
    /// Requisito de prueba (desbloqueo rápido) para ciertos grupos.
    static let testRequirement = 1
    /// Grupos con desbloqueo rápido (1 completado): RR y BL.
    static let quickUnlockCodes: Set<String> = ["RR", "BL"]

    /// Completaciones necesarias para un fonema/grupo. RR y BL son excepciones de
    /// prueba (1 completado); el resto requiere `normalRequirement` (3).
    static func requiredCompletions(forCode code: String) -> Int {
        quickUnlockCodes.contains(code) ? testRequirement : normalRequirement
    }

    // Fase 4B: cada skin tiene su animación Rive (.riv en Sources/Resources/Rive/).
    // Si un .riv faltara o fallara, la vista cae a placeholder sin crashear.
    static let all: [Skin] = [
        make("R",  "Rayo",   "hare.fill",                 riv: "skin_r"),
        make("RR", "Ronrro", "pawprint.fill",             riv: "skin_rr"),
        make("S",  "Sisi",   "sun.max.fill",              riv: "skin_s"),
        make("L",  "Lilo",   "moon.fill",                 riv: "skin_l"),
        make("TR", "Triko",  "tram.fill",                 riv: "skin_tr"),
        make("PR", "Priko",  "crown.fill",                riv: "skin_pr"),
        make("PL", "Pluki",  "fork.knife",                riv: "skin_pl"),
        make("BR", "Bruno",  "hand.wave.fill",            riv: "skin_br"),
        make("BL", "Blupi",  "square.stack.3d.up.fill",   riv: "skin_bl"),
    ]

    /// Skin asociada a un fonema/grupo, si existe.
    static func skin(forCode code: String) -> Skin? {
        all.first { $0.phonemeCode == code }
    }

    /// ¿El perfil ya desbloqueó esta skin? Derivado del progreso, no persistido.
    static func isUnlocked(_ skin: Skin, for profile: ChildProfile) -> Bool {
        profile.completionCount(forCode: skin.phonemeCode) >= skin.requiredCompletions
    }

    // MARK: - Helpers

    private static func make(_ code: String, _ name: String, _ symbol: String,
                             riv: String? = nil) -> Skin {
        Skin(
            id: "skin_\(code.lowercased())",
            name: name,
            phonemeCode: code,
            requiredCompletions: requiredCompletions(forCode: code),
            symbol: symbol,
            rivFileName: riv
        )
    }
}
