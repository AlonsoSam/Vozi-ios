import SwiftUI
import Supabase

/// Estado de "VOZI Premium" (Fase 6 demo, Fase 7.8 per-cuenta).
///
/// Premium sigue siendo una **simulación** (sin cobro real, sin Culqi, sin StoreKit).
/// Tiene dos modos, transparentes para el resto de la app:
///
/// - **Sin sesión → demo local**: el flag vive en `UserDefaults` (como en Fase 6).
///   La app funciona offline igual que siempre.
/// - **Con sesión → per-cuenta**: el flag vive en la tabla `entitlements` de Supabase
///   (`parent_id`, `is_premium`, `source='demo'`) y se sincroniza entre dispositivos
///   de la misma cuenta. El `UserDefaults` queda como caché local del último estado.
///
/// `isPremium` es el flag EFECTIVO que usa el gate del Home; la lógica de acceso
/// (`canAccess`) NO cambia: developer mode desbloquea todo, gratis solo R, Premium
/// activo desbloquea el resto.
@MainActor
final class PremiumStore: ObservableObject {

    /// De dónde proviene el estado actual (solo para mostrar en la UI).
    enum Source: Equatable {
        case localDemo   // sin sesión: demo local (UserDefaults)
        case account     // con sesión: entitlements de Supabase
    }

    private enum Keys {
        static let isPremium = "vozi.premium.isActive"
    }

    /// Flag efectivo de Premium. Solo se modifica desde aquí (local o remoto).
    @Published private(set) var isPremium: Bool
    /// Origen del estado actual, para la UI ("demo local" vs "cuenta").
    @Published private(set) var source: Source = .localDemo
    /// `true` mientras hay una operación remota de entitlement en curso.
    @Published private(set) var isWorking = false

    private let defaults: UserDefaults
    private let client: SupabaseClient?
    private var observeTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard,
         client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.defaults = defaults
        self.client = client
        self.isPremium = defaults.bool(forKey: Keys.isPremium)
        observeSession()
    }

    deinit { observeTask?.cancel() }

    // MARK: - Observación de sesión

    /// Sigue los cambios de sesión: al iniciar/restaurar sesión carga el entitlement
    /// de la cuenta; al cerrar sesión vuelve al modo demo local (sin crashear).
    private func observeSession() {
        guard let client else { source = .localDemo; return }
        observeTask = Task { [weak self] in
            for await change in client.auth.authStateChanges {
                switch change.event {
                case .signedIn, .initialSession, .tokenRefreshed, .userUpdated:
                    if change.session != nil {
                        await self?.refresh()
                    } else {
                        self?.fallBackToLocal()
                    }
                case .signedOut:
                    self?.fallBackToLocal()
                default:
                    break
                }
            }
        }
    }

    /// Vuelve al modo demo local conservando el último estado cacheado (no crashea,
    /// no borra nada). El flag efectivo queda como el último valor conocido.
    private func fallBackToLocal() {
        source = .localDemo
    }

    // MARK: - Carga remota (per-cuenta)

    /// Carga el entitlement de la cuenta. Si no existe la fila, la crea con
    /// `is_premium = false`, `source = 'demo'`. Sin sesión: no-op (queda demo local).
    func refresh() async {
        guard let client, let parentId = client.auth.currentUser?.id else {
            fallBackToLocal()
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let rows: [EntitlementRow] = try await client.from("entitlements")
                .select()
                .eq("parent_id", value: parentId.uuidString)
                .execute()
                .value

            if let row = rows.first {
                applyRemote(row.isPremium)
            } else {
                // No existe: crear fila por defecto para la cuenta.
                let new = EntitlementRow(parentId: parentId, isPremium: false, source: "demo")
                try await client.from("entitlements").insert(new).execute()
                applyRemote(false)
            }
            source = .account
        } catch {
            // Falla de red/permiso: se conserva el caché local; modo cuenta sin pisar.
            source = .account
        }
    }

    private func applyRemote(_ value: Bool) {
        isPremium = value
        defaults.set(value, forKey: Keys.isPremium)   // caché local
    }

    // MARK: - Activar / desactivar (demo)

    /// Cambia el estado Premium. Con sesión: actualiza `entitlements` y refleja local.
    /// Sin sesión: solo demo local (UserDefaults). Optimista: refleja local de
    /// inmediato y persiste remoto en segundo plano.
    func setPremium(_ value: Bool) async {
        // Reflejo local inmediato + caché (sirve también de fallback offline).
        isPremium = value
        defaults.set(value, forKey: Keys.isPremium)

        guard let client, let parentId = client.auth.currentUser?.id else {
            source = .localDemo
            return
        }
        source = .account
        isWorking = true
        defer { isWorking = false }
        do {
            let row = EntitlementRow(parentId: parentId, isPremium: value, source: "demo")
            try await client.from("entitlements")
                .upsert(row, onConflict: "parent_id", returning: .minimal)
                .execute()
        } catch {
            // Si falla el remoto, el estado local (demo) ya quedó aplicado; se
            // reconciliará en el próximo refresh (p. ej. al reiniciar sesión).
        }
    }

    /// Activa el Premium simulado (botón "Activar Premium demo").
    func activate() { Task { await setPremium(true) } }

    /// Desactiva el Premium simulado.
    func deactivate() { Task { await setPremium(false) } }

    /// Binding para el Toggle del panel adulto: enruta el cambio por `setPremium`.
    var premiumBinding: Binding<Bool> {
        Binding(get: { self.isPremium },
                set: { newValue in Task { await self.setPremium(newValue) } })
    }

    // MARK: - Gate de acceso (SIN CAMBIOS respecto a Fase 6)

    /// ¿El fonema/grupo está disponible sin Premium? Solo **R** es gratuito.
    /// `nil` (fonema desconocido) se considera de pago por seguridad.
    static func isFreePhoneme(_ phoneme: Phoneme?) -> Bool {
        phoneme == .r
    }

    /// ¿Se puede abrir este fonema con el estado actual? El modo desarrollador
    /// ignora el gate Premium (para pruebas), igual que ya ignora los candados.
    func canAccess(_ phoneme: Phoneme?) -> Bool {
        if DeveloperSettings.isDeveloperModeEnabled { return true }
        if isPremium { return true }
        return PremiumStore.isFreePhoneme(phoneme)
    }
}

// MARK: - DTO de la tabla `entitlements`

/// Mapeo con `entitlements`. `source` siempre 'demo' (simulado; sin pagos).
/// No se envían `created_at`/`updated_at` (defaults + trigger en el backend).
private struct EntitlementRow: Codable {
    let parentId: UUID
    let isPremium: Bool
    let source: String

    enum CodingKeys: String, CodingKey {
        case parentId = "parent_id"
        case isPremium = "is_premium"
        case source
    }
}
