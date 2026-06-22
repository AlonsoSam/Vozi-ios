import Foundation
import Supabase

/// Punto único de acceso al cliente de Supabase (Fase 7.1).
///
/// Local-first: VOZI funciona sin red usando SwiftData; este cliente es solo el
/// canal de sincronización que se usará en fases posteriores. En 7.1 NO se hace
/// auth ni sync: solo se deja el cliente configurado y verificable.
///
/// Las credenciales NO están hardcodeadas: se leen del Info.plist, que a su vez
/// las recibe (build settings `INFOPLIST_KEY_*`) desde `LocalSecrets.xcconfig`
/// (no versionado). Si faltan o son el placeholder, falla de forma controlada:
/// ruidoso en DEBUG (assertion) y silencioso-pero-logueado en release, sin
/// romper el arranque de la app.
enum SupabaseClientProvider {

    // MARK: - Config leída del Info.plist

    private struct Config {
        let url: URL
        let anonKey: String
    }

    /// Errores de configuración legibles (para depurar rápido en sustentación).
    enum ConfigError: LocalizedError {
        case missingURL
        case missingKey
        case placeholderURL
        case placeholderKey
        case invalidURL(String)

        var errorDescription: String? {
            switch self {
            case .missingURL:
                return "Falta SUPABASE_URL. Define el host en vozi-ios/LocalSecrets.xcconfig."
            case .missingKey:
                return "Falta SUPABASE_ANON_KEY. Define la anon key en vozi-ios/LocalSecrets.xcconfig."
            case .placeholderURL:
                return "SUPABASE_URL sigue con el valor de ejemplo. Reemplázalo por tu host real (sin https://)."
            case .placeholderKey:
                return "SUPABASE_ANON_KEY sigue con el valor de ejemplo. Reemplázalo por tu anon/public key real."
            case .invalidURL(let raw):
                return "SUPABASE_URL no es válida: «\(raw)». Usa solo el host, ej. abcdefgh.supabase.co"
            }
        }
    }

    // MARK: - Lectura + validación

    /// Lee y valida la configuración desde el Info.plist. `throws` si algo falta o
    /// quedó en el placeholder, para no construir un cliente inservible en silencio.
    private static func loadConfig(bundle: Bundle = .main) throws -> Config {
        let rawURL = string(forKey: "SUPABASE_URL", in: bundle)
        let rawKey = string(forKey: "SUPABASE_ANON_KEY", in: bundle)

        guard let rawURL, !rawURL.isEmpty else { throw ConfigError.missingURL }
        guard let rawKey, !rawKey.isEmpty else { throw ConfigError.missingKey }
        guard !rawURL.contains("PEGA_AQUI"), rawURL != "TU_HOST.supabase.co" else {
            throw ConfigError.placeholderURL
        }
        guard !rawKey.contains("PEGA_AQUI"), rawKey != "TU_ANON_PUBLIC_KEY" else {
            throw ConfigError.placeholderKey
        }

        // El host viene sin esquema (el "//" rompería el .xcconfig). Si por algún
        // motivo ya trae "https://", se respeta; si no, se antepone.
        let normalized = rawURL.contains("://") ? rawURL : "https://\(rawURL)"
        guard let url = URL(string: normalized), url.host != nil else {
            throw ConfigError.invalidURL(rawURL)
        }

        return Config(url: url, anonKey: rawKey)
    }

    private static func string(forKey key: String, in bundle: Bundle) -> String? {
        (bundle.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - API pública

    /// `true` si hay credenciales válidas (sin construir el cliente).
    static var isConfigured: Bool { (try? loadConfig()) != nil }

    /// Cliente compartido de Supabase. `nil` si la configuración falta o es inválida.
    ///
    /// En 7.1 nadie lo usa todavía, así que un `nil` no rompe la app: solo deja
    /// constancia clara. En DEBUG dispara una assertion para detectarlo temprano.
    static let shared: SupabaseClient? = {
        do {
            let config = try loadConfig()
            return SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        } catch {
            let message = "⚠️ VOZI · Supabase no configurado: \(error.localizedDescription)"
            #if DEBUG
            assertionFailure(message)
            #endif
            print(message)
            return nil
        }
    }()
}
