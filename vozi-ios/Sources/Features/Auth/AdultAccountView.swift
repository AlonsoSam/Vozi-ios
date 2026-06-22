import SwiftUI

/// Pantalla de cuenta del adulto (Fase 7.2). Vive dentro de la zona de adultos
/// (tras el PIN). Permite crear cuenta / iniciar sesión / cerrar sesión con
/// Supabase Auth (email + contraseña). El niño nunca ve ni usa esto.
///
/// La cuenta es solo la identidad para la sincronización futura: si no hay
/// sesión, la app sigue funcionando 100% local.
struct AdultAccountView: View {
    @EnvironmentObject private var auth: AuthService

    private enum Mode: String, CaseIterable {
        case signIn = "Iniciar sesión"
        case signUp = "Crear cuenta"
    }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?
    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: VoziTheme.Space.lg) {
                switch auth.state {
                case .unknown:
                    loadingState
                case .signedIn(let accountEmail):
                    signedInState(email: accountEmail)
                case .signedOut:
                    authForm
                }
            }
            .padding(VoziTheme.Space.lg)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .voziBackground()
        .navigationTitle("Cuenta del adulto")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Cargando sesión inicial

    private var loadingState: some View {
        VStack(spacing: VoziTheme.Space.md) {
            ProgressView()
            Text("Cargando tu cuenta…")
                .font(.vozi(.subheadline))
                .foregroundStyle(VoziTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Sesión iniciada

    private func signedInState(email: String?) -> some View {
        VStack(spacing: VoziTheme.Space.lg) {
            VoziHero(symbol: "person.crop.circle.badge.checkmark",
                     title: "Sesión iniciada",
                     subtitle: "Tu cuenta de adulto está lista para la sincronización.",
                     color: VoziTheme.mint)

            VoziSection(title: "Cuenta", symbol: "envelope.fill", color: VoziTheme.brand) {
                VStack(alignment: .leading, spacing: VoziTheme.Space.sm) {
                    Text(email ?? "Adulto")
                        .font(.vozi(.headline, weight: .bold))
                        .foregroundStyle(VoziTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Label("La sincronización entre dispositivos llegará pronto.",
                          systemImage: "icloud")
                        .font(.vozi(.footnote))
                        .foregroundStyle(VoziTheme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await auth.signOut() }
            } label: {
                Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(VoziSecondaryButtonStyle(tint: VoziTheme.coral))
            .disabled(auth.isWorking)

            privacyNote
        }
    }

    // MARK: - Formulario (crear cuenta / iniciar sesión)

    private var authForm: some View {
        VStack(spacing: VoziTheme.Space.lg) {
            VoziHero(symbol: "person.badge.key.fill",
                     title: "Cuenta del adulto",
                     subtitle: "Inicia sesión o crea una cuenta para sincronizar (próximamente). El niño no necesita cuenta.",
                     color: VoziTheme.lavender)

            Picker("Modo", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(spacing: VoziTheme.Space.md) {
                field("Correo", text: $email, symbol: "envelope.fill",
                      field: .email, secure: false)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)

                field("Contraseña", text: $password, symbol: "lock.fill",
                      field: .password, secure: true)
                    .textContentType(mode == .signUp ? .newPassword : .password)

                if let error = auth.errorMessage {
                    message(error, symbol: "exclamationmark.circle.fill", color: VoziTheme.coral)
                }
                if let info = auth.infoMessage {
                    message(info, symbol: "info.circle.fill", color: VoziTheme.brand)
                }
            }
            .padding(VoziTheme.Space.lg)
            .voziCard()

            Button {
                focused = nil
                Task { await submit() }
            } label: {
                if auth.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Label(mode.rawValue,
                          systemImage: mode == .signUp ? "person.crop.circle.badge.plus" : "arrow.right.circle.fill")
                }
            }
            .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.brand))
            .disabled(auth.isWorking || email.isEmpty || password.isEmpty)
            .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)

            privacyNote
        }
    }

    private func submit() async {
        switch mode {
        case .signIn: await auth.signIn(email: email, password: password)
        case .signUp: await auth.signUp(email: email, password: password)
        }
    }

    // MARK: - Subvistas

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, symbol: String,
                       field: Field, secure: Bool) -> some View {
        HStack(spacing: VoziTheme.Space.sm) {
            Image(systemName: symbol)
                .foregroundStyle(VoziTheme.brand)
                .frame(width: 24)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.vozi(.body, weight: .medium))
            .focused($focused, equals: field)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(VoziTheme.brand.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: VoziTheme.Radius.sm, style: .continuous))
    }

    private func message(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.vozi(.footnote, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyNote: some View {
        Label("Tu correo y contraseña los gestiona Supabase de forma segura. VOZI no guarda tu contraseña.",
              systemImage: "lock.shield")
            .font(.vozi(.caption))
            .foregroundStyle(VoziTheme.inkSoft)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, VoziTheme.Space.xs)
    }
}
