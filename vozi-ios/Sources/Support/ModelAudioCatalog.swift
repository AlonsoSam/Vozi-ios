import Foundation

/// Resuelve los clips de "audio modelo" personalizados (spec §10, Fase 5).
///
/// Hay dos familias de audio modelo local, ambas OPCIONALES (si faltan, la app
/// cae a TTS o no reproduce nada, nunca crashea):
///
/// 1. Clip curado por `audioKey` (`.m4a`) — convención previa.
/// 2. Audio por PALABRA (`.mp3`) para el botón Escuchar y frases de FEEDBACK
///    (acierto / fallo / fin de sesión), generados manualmente (p. ej. Fish
///    Audio) y colocados en `Resources/Audio/`.
///
/// El bundle aplana los recursos, así que basta el nombre de archivo (único por
/// diseño) sin importar en qué subcarpeta de `Audio/` viva.
///
/// Privacidad: aquí solo viven audios MODELO curados (voz de referencia para que
/// el niño escuche). Nunca se guarda ni reproduce audio crudo del niño.
enum ModelAudioCatalog {

    /// URL del clip `.m4a` empaquetado para un `audioKey`, o `nil` si no existe.
    static func url(forKey key: String?) -> URL? {
        guard let key, !key.isEmpty else { return nil }
        return Bundle.main.url(forResource: key, withExtension: "m4a")
    }

    // MARK: - Audio por palabra (Fase 5)

    /// Normaliza una palabra al nombre de archivo de su audio: minúsculas, sin
    /// tildes, espacios → guion bajo. Espejo de `WordImageCatalog.imageKey`
    /// pero sin prefijo. Ej: "ratón" → "raton", "blíster" → "blister".
    static func normalizedWord(_ word: String) -> String {
        word.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
    }

    /// URL del `.mp3` modelo de una palabra (carpeta `Audio/Words/`), o `nil`.
    static func wordURL(for word: String) -> URL? {
        let name = normalizedWord(word)
        guard !name.isEmpty else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "mp3")
    }

    // MARK: - Frases de feedback (Fase 5)

    /// Familias de frases de feedback. El `prefix` y el rango definen los nombres
    /// de archivo esperados (ej. `correct_01.mp3` … `correct_10.mp3`).
    enum Feedback {
        case correct
        case incorrect
        case sessionComplete

        var prefix: String {
            switch self {
            case .correct:         return "correct"
            case .incorrect:       return "incorrect"
            case .sessionComplete: return "session_complete"
            }
        }

        /// Cantidad máxima de frases esperadas para esta familia.
        var maxIndex: Int {
            switch self {
            case .correct, .incorrect: return 10
            case .sessionComplete:     return 5
            }
        }
    }

    /// URL de una frase de feedback aleatoria de la familia, eligiendo solo entre
    /// los archivos que existen en el bundle. Devuelve `nil` si no hay ninguno
    /// (la app simplemente no reproduce feedback de audio, sin crashear).
    static func randomFeedbackURL(_ kind: Feedback) -> URL? {
        let available = (1...kind.maxIndex).compactMap { i -> URL? in
            let name = String(format: "%@_%02d", kind.prefix, i)
            return Bundle.main.url(forResource: name, withExtension: "mp3")
        }
        return available.randomElement()
    }
}
