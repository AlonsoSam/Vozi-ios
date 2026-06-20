import Foundation

/// Los 5 fonemas del MVP (spec §8). La arquitectura es escalable a 8
/// (R, RR, S, L, T, D, CH, TR) añadiendo casos aquí y su contenido en `ContentBank`.
///
/// `rawValue` es el código estable ("R", "RR", ...) que ya usa `SpeechAttempt`
/// y que mapeará a la columna `phoneme_code` en Supabase (Fase 1+), sin conectarla aún.
enum Phoneme: String, CaseIterable, Identifiable, Codable {
    case r  = "R"
    case rr = "RR"
    case s  = "S"
    case l  = "L"
    case tr = "TR"

    var id: String { rawValue }

    /// Código estable para persistencia y futuro backend.
    var code: String { rawValue }

    /// Nombre corto para mostrar al niño (texto mínimo, spec §11).
    var displayName: String {
        switch self {
        case .r:  return "R"
        case .rr: return "RR"
        case .s:  return "S"
        case .l:  return "L"
        case .tr: return "TR"
        }
    }

    /// Icono placeholder (SF Symbol). Se reemplazará por ilustración propia en Fase 4.
    var iconSystemName: String {
        switch self {
        case .r:  return "hare.fill"        // rana/ratón
        case .rr: return "pawprint.fill"    // perro
        case .s:  return "sun.max.fill"     // sol
        case .l:  return "moon.fill"        // luna
        case .tr: return "tram.fill"        // tren
        }
    }

    /// Orden de presentación en el Home del niño.
    var order: Int {
        switch self {
        case .r:  return 0
        case .rr: return 1
        case .s:  return 2
        case .l:  return 3
        case .tr: return 4
        }
    }
}
