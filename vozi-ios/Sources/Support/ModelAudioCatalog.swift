import Foundation

/// Resuelve los clips de "audio modelo" personalizados (spec §10).
///
/// Convención: archivos empaquetados en el bundle nombrados como el `audioKey`,
/// con extensión `.m4a` (ej. audioKey "audio_rana" → "audio_rana.m4a"). En Fase 2
/// el catálogo puede estar vacío: `ModelVoiceService` cae a TTS como respaldo.
///
/// Privacidad: aquí solo viven audios MODELO curados (voz de referencia para que
/// el niño escuche). Nunca se guarda ni reproduce audio crudo del niño.
enum ModelAudioCatalog {

    /// URL del clip empaquetado para un `audioKey`, o `nil` si no existe.
    static func url(forKey key: String?) -> URL? {
        guard let key, !key.isEmpty else { return nil }
        return Bundle.main.url(forResource: key, withExtension: "m4a")
    }
}
