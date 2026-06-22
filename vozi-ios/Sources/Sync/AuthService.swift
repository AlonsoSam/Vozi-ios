import Foundation
import Supabase

/// Autenticación del ADULTO con Supabase Auth (email + contraseña) — Fase 7.2.
///
/// Local-first: la app funciona sin sesión (todo el flujo del niño es local con
/// SwiftData). Esta cuenta es solo la identidad del adulto para la sincronización
/// futura; el niño NUNCA inicia sesión. El PIN local de `ParentGateView` se
/// mantiene como gate rápido de la zona de adultos, independiente de esto.
///
/// Privacidad: nunca se imprime email ni contraseña. La contraseña no se guarda
/// manualmente: Supabase Auth gestiona la sesión (Keychain) y el refresco de token.
@MainActor
final class AuthService: ObservableObject {

    /// Estado de sesión observable por la UI.
    enum SessionState: Equatable {
        case unknown                 // cargando la sesión inicial (al arrancar)
        case signedOut               // sin sesión (la app sigue funcionando local)
        case signedIn(email: String?)
    }

    @Published private(set) var state: SessionState = .unknown
    /// `true` mientras hay una operación de auth en curso (deshabilita botones).
    @Published private(set) var isWorking = false
    /// Mensaje de error legible (sin filtrar credenciales). `nil` si no hay error.
    @Published var errorMessage: String?
    /// Mensaje informativo (p. ej. "confirma tu correo"). `nil` si no aplica.
    @Published var infoMessage: String?

    private let client: SupabaseClient?
    private var observeTask: Task<Void, Never>?

    init(client: SupabaseClient? = SupabaseClientProvider.shared) {
        self.client = client
        observeSession()
    }

    deinit { observeTask?.cancel() }

    // MARK: - Estado derivado

    /// `true` si Supabase está configurado (anon key + URL válidas).
    var isConfigured: Bool { client != nil }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var currentEmail: String? {
        if case .signedIn(let email) = state { return email }
        return nil
    }

    // MARK: - Observación de sesión (incluye restauración al abrir la app)

    private func observeSession() {
        guard let client else {
            // Sin configuración Supabase: la app sigue local, solo no hay cuenta.
            state = .signedOut
            return
        }
        observeTask = Task { [weak self] in
            // `authStateChanges` emite `.initialSession` al suscribirse, restaurando
            // la sesión persistida en Keychain (requisito: recuperar sesión activa).
            for await change in client.auth.authStateChanges {
                self?.apply(session: change.session)
            }
        }
    }

    private func apply(session: Session?) {
        if let session {
            state = .signedIn(email: session.user.email)
        } else {
            state = .signedOut
        }
    }

    // MARK: - Acciones

    /// Registra un adulto nuevo. Si el proyecto exige confirmar correo, la sesión
    /// llega `nil` y se informa al adulto (no es error).
    func signUp(email: String, password: String) async {
        guard let client else { errorMessage = notConfiguredMessage; return }
        guard validate(email: email, password: password) else { return }

        await run {
            let response = try await client.auth.signUp(
                email: Self.normalize(email),
                password: password
            )
            if response.session == nil {
                // Confirmación de correo activada en Supabase: aún no hay sesión.
                self.infoMessage = "Cuenta creada. Revisa tu correo para confirmarla y luego inicia sesión."
            }
            // Si hay sesión, `authStateChanges` ya actualiza el estado a signedIn.
        }
    }

    /// Inicia sesión con email + contraseña.
    func signIn(email: String, password: String) async {
        guard let client else { errorMessage = notConfiguredMessage; return }
        guard validate(email: email, password: password) else { return }

        await run {
            _ = try await client.auth.signIn(
                email: Self.normalize(email),
                password: password
            )
            // `authStateChanges` actualiza el estado a signedIn.
        }
    }

    /// Cierra la sesión actual. La app sigue funcionando local.
    func signOut() async {
        guard let client else { state = .signedOut; return }
        await run {
            try await client.auth.signOut()
            // `authStateChanges` actualiza el estado a signedOut.
        }
    }

    // MARK: - Helpers

    /// Ejecuta una operación de auth gestionando `isWorking` y errores, sin loguear
    /// credenciales ni el error crudo (que podría contener el email).
    private func run(_ operation: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    private func validate(email: String, password: String) -> Bool {
        errorMessage = nil
        let trimmed = Self.normalize(email)
        guard trimmed.contains("@"), trimmed.contains("."), trimmed.count >= 5 else {
            errorMessage = "Escribe un correo válido."
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "La contraseña debe tener al menos 6 caracteres."
            return false
        }
        return true
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var notConfiguredMessage: String {
        "Supabase no está configurado en esta instalación. La app funciona local igual."
    }

    /// Traduce el error a un mensaje claro en español SIN exponer credenciales.
    /// No se imprime el error crudo a propósito (podría contener el email).
    private static func friendlyMessage(for error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("invalid login") || text.contains("invalid credentials") {
            return "Correo o contraseña incorrectos."
        }
        if text.contains("already registered") || text.contains("already been registered") || text.contains("user already") {
            return "Ese correo ya tiene una cuenta. Inicia sesión."
        }
        if text.contains("email not confirmed") || text.contains("not confirmed") {
            return "Confirma tu correo antes de iniciar sesión."
        }
        if text.contains("password") && (text.contains("least") || text.contains("weak") || text.contains("6")) {
            return "La contraseña debe tener al menos 6 caracteres."
        }
        if text.contains("rate limit") || text.contains("too many") {
            return "Demasiados intentos. Espera un momento e inténtalo de nuevo."
        }
        if text.contains("offline") || text.contains("network") || text.contains("connection")
            || text.contains("internet") || text.contains("timed out") {
            return "Sin conexión. Revisa tu internet e inténtalo otra vez."
        }
        return "No se pudo completar. Inténtalo de nuevo."
    }
}
