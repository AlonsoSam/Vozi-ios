import SwiftUI
import SwiftData

/// Panel mínimo de padres (spec §13): lista de perfiles con resumen de progreso.
/// Tocar un perfil abre su detalle (progreso, intentos, juicio adulto).
/// Local/offline; sin Supabase ni reportes PDF (fases posteriores).
struct ParentPanelView: View {
    @Query(sort: \ChildProfile.createdAt, order: .forward) private var profiles: [ChildProfile]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var sync: SyncService
    @State private var showPremium = false
    /// Cambios locales pendientes de subir (para la migración/subida inicial).
    @State private var pendingChanges = 0
    /// Confirmación de borrado de datos locales de prueba (solo desarrollo).
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VoziTheme.Space.lg) {
                    accountSection
                    premiumSection
                    profilesSection
                    developerSection
                }
                .padding(VoziTheme.Space.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .voziBackground()
            .onAppear { pendingChanges = sync.pendingCount(in: context) }
            .navigationTitle("Panel de adultos")
            .navigationDestination(for: ChildProfile.self) { profile in
                ParentProfileDetailView(profile: profile)
            }
            .sheet(isPresented: $showPremium) {
                PremiumView()
            }
        }
    }

    /// Cuenta del adulto (Fase 7.2): estado de sesión + acceso a la pantalla de
    /// crear cuenta / iniciar sesión. Convive con el PIN local (gate de la zona).
    private var accountSection: some View {
        VoziSection(title: "Cuenta del adulto", symbol: "person.crop.circle.fill",
                    color: VoziTheme.mint) {
            NavigationLink {
                AdultAccountView()
            } label: {
                HStack(spacing: VoziTheme.Space.md) {
                    Image(systemName: auth.isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(VoziTheme.gradient(auth.isSignedIn ? VoziTheme.success : VoziTheme.neutral),
                                    in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.isSignedIn ? "Sesión iniciada" : "Sin sesión")
                            .font(.vozi(.headline, weight: .bold))
                            .foregroundStyle(VoziTheme.ink)
                        Text(auth.isSignedIn ? (auth.currentEmail ?? "Cuenta activa")
                                             : "Crea una cuenta o inicia sesión")
                            .font(.vozi(.footnote))
                            .foregroundStyle(VoziTheme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(VoziTheme.inkSoft)
                }
                .padding(VoziTheme.Space.md)
                .background(VoziTheme.mint.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous))
            }
            .buttonStyle(VoziPressableStyle())

            if auth.isSignedIn {
                syncControls
            } else {
                Text("La app funciona local sin sesión. Inicia sesión para sincronizar tus perfiles entre dispositivos.")
                    .font(.vozi(.footnote))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Sync manual de perfiles (Fase 7.4: solo `children`). Botón + estado + error.
    @ViewBuilder
    private var syncControls: some View {
        let isSyncing = sync.state == .syncing

        // Migración/subida inicial: avisa cuántos cambios locales hay por subir,
        // y destaca la primera sincronización (datos creados offline antes de la cuenta).
        if pendingChanges > 0 {
            Label(sync.hasNeverSynced
                  ? "Primera sincronización: \(pendingChanges) dato(s) local(es) por subir."
                  : "\(pendingChanges) cambio(s) local(es) por subir.",
                  systemImage: "tray.and.arrow.up.fill")
                .font(.vozi(.footnote, weight: .semibold))
                .foregroundStyle(VoziTheme.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        Button {
            Task {
                await sync.sync(context: context)
                pendingChanges = sync.pendingCount(in: context)
            }
        } label: {
            if isSyncing {
                ProgressView().tint(.white)
            } else {
                Label(sync.hasNeverSynced && pendingChanges > 0 ? "Subir datos locales" : "Sincronizar datos",
                      systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .buttonStyle(VoziBigButtonStyle(fill: VoziTheme.brand))
        .disabled(isSyncing)

        // Estado de la última sincronización / error controlado.
        Group {
            switch sync.state {
            case .failure(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(VoziTheme.coral)
            case .syncing:
                Label("Sincronizando datos…", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(VoziTheme.inkSoft)
            default:
                Label(lastSyncText, systemImage: "clock.arrow.circlepath")
                    .foregroundStyle(VoziTheme.inkSoft)
            }
        }
        .font(.vozi(.footnote, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)

        Text("Se sincronizan perfiles, progreso e intentos (solo métricas educativas). Premium aún no se sube; nunca se sube audio ni la transcripción del niño.")
            .font(.vozi(.caption))
            .foregroundStyle(VoziTheme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastSyncText: String {
        guard let last = sync.lastSync else { return "Aún no has sincronizado." }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Última sincronización: \(formatter.string(from: last))"
    }

    /// Zona de pruebas (desarrollo): borra los datos locales SwiftData de prueba.
    /// 100% local: NO sube nada ni toca Supabase. Con confirmación destructiva.
    private var developerSection: some View {
        VoziSection(title: "Zona de pruebas", symbol: "hammer.fill", color: VoziTheme.coral) {
            VStack(alignment: .leading, spacing: VoziTheme.Space.md) {
                Text("Borra los datos locales de este dispositivo (perfiles, progreso e intentos). No sube nada y no borra nada en Supabase.")
                    .font(.vozi(.footnote))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Borrar datos locales de prueba", systemImage: "trash.fill")
                }
                .buttonStyle(VoziSecondaryButtonStyle(tint: VoziTheme.coral))
            }
        }
        .confirmationDialog("¿Borrar todos los datos locales?",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { wipeLocalData() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se eliminarán perfiles, progreso e intentos de ESTE dispositivo. No se sube nada y no se borra nada en Supabase. No se puede deshacer.")
        }
    }

    /// Borra los datos locales y deja `pendingChanges` en 0 (no sincroniza).
    private func wipeLocalData() {
        DeveloperDataReset.wipeLocalData(in: context)
        pendingChanges = sync.pendingCount(in: context)   // -> 0
    }

    private var premiumSection: some View {
        VoziSection(title: "VOZI Premium", symbol: "crown.fill", color: VoziTheme.sunshine) {
            VStack(spacing: VoziTheme.Space.md) {
                HStack {
                    VoziStatusChip(status: premium.isPremium ? .premiumActive : .premiumInactive)
                    Spacer()
                    Toggle("", isOn: premium.premiumBinding)
                        .labelsHidden()
                        .tint(VoziTheme.sunshine)
                        .disabled(premium.isWorking)
                }

                // Origen del estado: per-cuenta (con sesión) o demo local (sin sesión).
                Label(premium.source == .account
                      ? "Premium de la cuenta (sincroniza entre dispositivos)."
                      : "Premium demo local (sin sesión).",
                      systemImage: premium.source == .account ? "person.icloud.fill" : "iphone")
                    .font(.vozi(.footnote))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button { showPremium = true } label: {
                    Label("Ver planes Premium", systemImage: "sparkles")
                }
                .buttonStyle(VoziSecondaryButtonStyle(tint: VoziTheme.sunshine))

                Text("Simulación para sustentación: sin cobro real. En modo gratuito solo el grupo R está disponible; Premium desbloquea los demás fonemas.")
                    .font(.vozi(.footnote))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var profilesSection: some View {
        VoziSection(title: "Perfiles", symbol: "person.2.fill", color: VoziTheme.brand) {
            if profiles.isEmpty {
                Text("Aún no hay perfiles. Crea uno en la pestaña Perfiles.")
                    .font(.vozi(.subheadline))
                    .foregroundStyle(VoziTheme.inkSoft)
            } else {
                VStack(spacing: VoziTheme.Space.sm) {
                    ForEach(profiles) { profile in
                        NavigationLink(value: profile) {
                            ParentProfileRow(profile: profile)
                        }
                        .buttonStyle(VoziPressableStyle())
                    }
                }
            }
        }
    }
}

/// Fila-resumen de un perfil en el panel.
private struct ParentProfileRow: View {
    let profile: ChildProfile

    private var phonemesCompleted: Int {
        profile.phonemeProgress.filter { $0.status == .completed }.count
    }
    private var stagesCompleted: Int {
        profile.phonemeProgress.flatMap { $0.stages }.filter { $0.status == .completed }.count
    }

    var body: some View {
        let avatar = AvatarCatalog.option(for: profile.avatarKey)
        HStack(spacing: VoziTheme.Space.md) {
            Image(systemName: avatar.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(VoziTheme.gradient(avatar.tint), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.vozi(.headline, weight: .bold))
                    .foregroundStyle(VoziTheme.ink)
                Text("\(profile.ageBand.rawValue) años · \(phonemesCompleted) fonemas · \(stagesCompleted) etapas")
                    .font(.vozi(.footnote))
                    .foregroundStyle(VoziTheme.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(VoziTheme.inkSoft)
        }
        .padding(VoziTheme.Space.md)
        .background(VoziTheme.brand.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous))
    }
}
