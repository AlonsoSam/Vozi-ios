import Foundation

/// Lectura segura de credenciales de Azure Speech.
///
/// Los valores se inyectan en el Info.plist desde `LocalSecrets.xcconfig`
/// (build settings `AZURE_SPEECH_*`). Nunca se hardcodean en código ni se
/// imprimen/loguean: solo se exponen para construir la petición.
///
/// Privacidad (spec §6/§7): la key vive solo en el archivo local (gitignored)
/// y en el Info.plist de la build local; jamás se envía a logs ni a otros lados.
enum AzureSecrets {

    static var key: String { value("AZURE_SPEECH_KEY") }
    static var region: String { value("AZURE_SPEECH_REGION") }
    static var endpoint: String { value("AZURE_SPEECH_ENDPOINT") }

    /// Azure se considera configurado si hay key y región. Sin esto, el flujo
    /// cae al reconocimiento de Apple (fallback).
    static var isConfigured: Bool {
        !key.isEmpty && !region.isEmpty
    }

    private static func value(_ k: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: k) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
