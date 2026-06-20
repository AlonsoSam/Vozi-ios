import Foundation
import Speech

struct LocaleOption: Identifiable, Hashable {
    let id: String      // "es-PE"
    let label: String   // "Español (Perú)"
}

/// Locales de prueba para calibración. Preferente: es-PE.
enum SupportedLocales {
    static let candidates = ["es-PE", "es-MX", "es-ES"]
    static let labels: [String: String] = [
        "es-PE": "Español (Perú)",
        "es-MX": "Español (México)",
        "es-ES": "Español (España)"
    ]

    /// Devuelve los candidatos efectivamente soportados por el dispositivo.
    /// Si ninguno está soportado, igual los ofrece para poder registrar el intento.
    static func available() -> [LocaleOption] {
        let supported = Set(SFSpeechRecognizer.supportedLocales().map {
            $0.identifier.replacingOccurrences(of: "_", with: "-")
        })
        let options = candidates
            .filter { supported.contains($0) }
            .map { LocaleOption(id: $0, label: labels[$0] ?? $0) }
        return options.isEmpty
            ? candidates.map { LocaleOption(id: $0, label: labels[$0] ?? $0) }
            : options
    }

    /// es-PE si está disponible; si no, el primero.
    static func preferred(in options: [LocaleOption]) -> String {
        options.first(where: { $0.id == "es-PE" })?.id ?? options.first?.id ?? "es-PE"
    }
}
