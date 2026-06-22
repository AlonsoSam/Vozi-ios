import Foundation
import SwiftData
import Supabase

/// Sincronización con Supabase — Fase 7.5.
///
/// Local-first: SwiftData es la fuente de verdad; Supabase es el espejo remoto.
/// La app funciona sin red y sin sesión: si no hay cliente configurado o no hay
/// adulto autenticado, `sync` es un no-op (no crashea, no bloquea).
///
/// Alcance actual: `children` → `phoneme_progress` → `stage_progress` →
/// `speech_attempts` (push append-only). NO se sincronizan entitlements, premium
/// ni recompensas. Nunca se sube audio ni `rawTranscription`.
@MainActor
final class SyncService: ObservableObject {

    enum SyncState: Equatable {
        case idle
        case syncing
        case success(Date)
        case failure(String)
    }

    @Published private(set) var state: SyncState = .idle
    /// Marca de la última sincronización exitosa (persistida en UserDefaults).
    @Published private(set) var lastSync: Date?

    private let client: SupabaseClient?
    private let defaults: UserDefaults
    private let lastSyncKey = "vozi.sync.children.lastSync"

    init(client: SupabaseClient? = SupabaseClientProvider.shared,
         defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        let stored = defaults.double(forKey: lastSyncKey)
        self.lastSync = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// `true` si hay cliente configurado y un adulto con sesión activa.
    var canSync: Bool { client?.auth.currentUser != nil }

    /// `true` si nunca se ha sincronizado en esta instalación (primera subida).
    var hasNeverSynced: Bool { lastSync == nil }

    /// Cuenta los datos locales pendientes de subir (`isDirty`) en los 4 modelos
    /// sincronizables. Solo lectura: NO modifica nada. Sirve para que la UI muestre
    /// claramente cuánto falta por subir en la migración/subida inicial.
    func pendingCount(in context: ModelContext) -> Int {
        let children = (try? context.fetch(FetchDescriptor<ChildProfile>()).filter(\.isDirty).count) ?? 0
        let phonemes = (try? context.fetch(FetchDescriptor<PhonemeProgress>()).filter(\.isDirty).count) ?? 0
        let stages   = (try? context.fetch(FetchDescriptor<StageProgress>()).filter(\.isDirty).count) ?? 0
        let attempts = (try? context.fetch(FetchDescriptor<SpeechAttempt>()).filter(\.isDirty).count) ?? 0
        return children + phonemes + stages + attempts
    }

    // MARK: - Orquestación

    /// Sincroniza children y, luego, el progreso (phoneme_progress y stage_progress).
    /// Cada entidad hace push (de lo `isDirty`) y luego pull (merge local-first).
    /// No-op si no hay sesión.
    func sync(context: ModelContext) async {
        guard let client else { return }                         // sin Supabase: local
        guard let parentId = client.auth.currentUser?.id else {  // sin sesión: no sync
            state = .idle
            return
        }
        guard state != .syncing else { return }

        state = .syncing
        do {
            // children primero: phoneme_progress y stage_progress tienen FK a children.
            try await pushChildren(context: context, parentId: parentId, client: client)
            try await pullChildren(context: context, client: client)

            try await pushPhonemeProgress(context: context, client: client)
            try await pullPhonemeProgress(context: context, client: client)

            try await pushStageProgress(context: context, client: client)
            try await pullStageProgress(context: context, client: client)

            // speech_attempts: append-only, solo push (sin update/delete/pull).
            try await pushSpeechAttempts(context: context, client: client)

            let now = Date()
            lastSync = now
            defaults.set(now.timeIntervalSince1970, forKey: lastSyncKey)
            state = .success(now)
        } catch {
            state = .failure(Self.friendlyMessage(for: error))
        }
    }

    // MARK: - children (push / pull)

    private func pushChildren(context: ModelContext, parentId: UUID, client: SupabaseClient) async throws {
        let dirty = try context.fetch(FetchDescriptor<ChildProfile>()).filter(\.isDirty)
        guard !dirty.isEmpty else { return }

        let rows = dirty.map { ChildRow(from: $0, parentId: parentId) }
        try await client.from("children")
            .upsert(rows, onConflict: "id", returning: .minimal)
            .execute()

        for profile in dirty { profile.isDirty = false }
        try? context.save()
    }

    private func pullChildren(context: ModelContext, client: SupabaseClient) async throws {
        let remote: [ChildRow] = try await client.from("children").select().execute().value
        let locals = try context.fetch(FetchDescriptor<ChildProfile>())
        var byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })

        for row in remote {
            if row.deletedAt != nil { continue }   // tombstone: se aplicará en fase de borrado
            if let local = byId[row.id] {
                if !local.isDirty, row.updatedAt > local.updatedAt { apply(row, to: local) }
            } else {
                let created = makeLocalProfile(from: row)
                context.insert(created)
                byId[row.id] = created
            }
        }
        try? context.save()
    }

    // MARK: - phoneme_progress (push / pull)

    private func pushPhonemeProgress(context: ModelContext, client: SupabaseClient) async throws {
        let dirty = try context.fetch(FetchDescriptor<PhonemeProgress>())
            .filter { $0.isDirty && $0.child != nil }
        guard !dirty.isEmpty else { return }

        let rows = dirty.compactMap { PhonemeProgressRow(from: $0) }
        // onConflict = clave natural (child_id, phoneme_code): respeta el unique y
        // evita duplicar aunque el id local difiera del remoto (placeholders 7.4).
        try await client.from("phoneme_progress")
            .upsert(rows, onConflict: "child_id,phoneme_code", returning: .minimal)
            .execute()

        for pp in dirty { pp.isDirty = false }
        try? context.save()
    }

    private func pullPhonemeProgress(context: ModelContext, client: SupabaseClient) async throws {
        let remote: [PhonemeProgressRow] = try await client.from("phoneme_progress")
            .select().execute().value

        let locals = try context.fetch(FetchDescriptor<PhonemeProgress>())
        // Índice por clave natural para reconciliar placeholders sin duplicar.
        var byKey: [String: PhonemeProgress] = [:]
        for pp in locals where pp.child != nil {
            byKey[Self.key(pp.child!.id, pp.phonemeCode)] = pp
        }
        let childrenById = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<ChildProfile>()).map { ($0.id, $0) })

        for row in remote {
            if row.deletedAt != nil { continue }
            if let local = byKey[Self.key(row.childId, row.phonemeCode)] {
                if !local.isDirty, row.updatedAt > local.updatedAt { apply(row, to: local) }
            } else if let child = childrenById[row.childId] {
                let created = makePhonemeProgress(from: row, child: child)
                context.insert(created)
                byKey[Self.key(row.childId, row.phonemeCode)] = created
            }
        }
        try? context.save()
    }

    // MARK: - stage_progress (push / pull)

    private func pushStageProgress(context: ModelContext, client: SupabaseClient) async throws {
        let dirty = try context.fetch(FetchDescriptor<StageProgress>())
            .filter { $0.isDirty && $0.phonemeProgress?.child != nil }
        guard !dirty.isEmpty else { return }

        let rows = dirty.compactMap { StageProgressRow(from: $0) }
        try await client.from("stage_progress")
            .upsert(rows, onConflict: "child_id,phoneme_code,stage", returning: .minimal)
            .execute()

        for sp in dirty { sp.isDirty = false }
        try? context.save()
    }

    private func pullStageProgress(context: ModelContext, client: SupabaseClient) async throws {
        let remote: [StageProgressRow] = try await client.from("stage_progress")
            .select().execute().value

        let localStages = try context.fetch(FetchDescriptor<StageProgress>())
        var byKey: [String: StageProgress] = [:]
        for sp in localStages {
            guard let pp = sp.phonemeProgress, let child = pp.child else { continue }
            byKey[Self.key(child.id, pp.phonemeCode, sp.stageRaw)] = sp
        }
        // Para crear etapas faltantes: índice de phoneme_progress por clave natural.
        var phonemesByKey: [String: PhonemeProgress] = [:]
        for pp in try context.fetch(FetchDescriptor<PhonemeProgress>()) where pp.child != nil {
            phonemesByKey[Self.key(pp.child!.id, pp.phonemeCode)] = pp
        }

        for row in remote {
            if row.deletedAt != nil { continue }
            if let local = byKey[Self.key(row.childId, row.phonemeCode, row.stage)] {
                if !local.isDirty, row.updatedAt > local.updatedAt { apply(row, to: local) }
            } else if let parent = phonemesByKey[Self.key(row.childId, row.phonemeCode)] {
                let created = makeStageProgress(from: row, parent: parent)
                context.insert(created)
                byKey[Self.key(row.childId, row.phonemeCode, row.stage)] = created
            }
        }
        try? context.save()
    }

    // MARK: - speech_attempts (push append-only)

    /// Sube los intentos locales `isDirty` en dos fases (Fase 7.6.1):
    ///
    /// 1) **Append**: `upsert(onConflict:"id", ignoreDuplicates:true)` =
    ///    `INSERT ... ON CONFLICT (id) DO NOTHING`. Inserta los nuevos y NO duplica
    ///    ni modifica los existentes (intento = registro inmutable).
    /// 2) **Juicio adulto**: para los intentos ya existentes cuyo `human_judgment`
    ///    cambió tras el primer push, se hace `UPDATE` SOLO de esa columna
    ///    (`update(["human_judgment": ...]).in("id", ...)`). El backend bloquea por
    ///    column-privilege cualquier intento de tocar otra columna.
    ///
    /// Privacidad: el DTO y el UPDATE NO incluyen `rawTranscription` ni audio.
    private func pushSpeechAttempts(context: ModelContext, client: SupabaseClient) async throws {
        let dirty = try context.fetch(FetchDescriptor<SpeechAttempt>())
            .filter { $0.isDirty && $0.child != nil }
        guard !dirty.isEmpty else { return }

        // 1) Append-only: crea los nuevos, ignora los que ya existen por id (retry).
        let rows = dirty.compactMap { SpeechAttemptRow(from: $0) }
        try await client.from("speech_attempts")
            .upsert(rows, onConflict: "id", returning: .minimal, ignoreDuplicates: true)
            .execute()

        // 2) Propaga SOLO el juicio adulto. Se agrupa por valor para 1 PATCH por
        //    valor distinto. Cubre tanto recién insertados (no-op) como los que ya
        //    estaban en remoto y cambiaron de juicio. No toca ninguna otra columna.
        let byJudgment = Dictionary(grouping: dirty, by: { $0.humanJudgment })
        for (judgment, attempts) in byJudgment {
            let ids = attempts.map { $0.id.uuidString }
            try await client.from("speech_attempts")
                .update(["human_judgment": judgment], returning: .minimal)
                .in("id", values: ids)
                .execute()
        }

        // Sincronizados: dejan de estar pendientes. No se tocan timestamps locales.
        for attempt in dirty { attempt.isDirty = false }
        try? context.save()
    }

    // MARK: - Apply (remoto → local, sin marcar dirty; adopta el id remoto)

    private func apply(_ row: ChildRow, to profile: ChildProfile) {
        profile.name = row.name
        profile.ageBandRaw = row.ageBand
        profile.avatarKey = row.avatarKey
        profile.points = row.points
        profile.updatedAt = row.updatedAt
        profile.deletedAt = row.deletedAt
        profile.isDirty = false
    }

    private func apply(_ row: PhonemeProgressRow, to pp: PhonemeProgress) {
        pp.id = row.id                      // converge el id (reemplaza placeholder 7.4)
        pp.statusRaw = row.status
        pp.completionCount = row.completionCount
        pp.updatedAt = row.updatedAt
        pp.deletedAt = row.deletedAt
        pp.isDirty = false
    }

    private func apply(_ row: StageProgressRow, to sp: StageProgress) {
        sp.id = row.id
        sp.statusRaw = row.status
        sp.itemsCompleted = row.itemsCompleted
        sp.lastPracticedAt = row.lastPracticedAt
        sp.updatedAt = row.updatedAt
        sp.deletedAt = row.deletedAt
        sp.isDirty = false
    }

    // MARK: - Creación de filas locales nuevas desde remoto

    /// Perfil remoto nuevo (otro dispositivo). Se siembra el árbol de progreso como
    /// PLACEHOLDER local (no-dirty, `updatedAt` antiguo) para que el Home no quede
    /// vacío; el pull de progreso real lo reemplaza por clave natural sin duplicar.
    private func makeLocalProfile(from row: ChildRow) -> ChildProfile {
        let profile = ChildProfile(
            name: row.name,
            ageBand: AgeBand(rawValue: row.ageBand) ?? .young,
            avatarKey: row.avatarKey
        )
        profile.id = row.id
        profile.points = row.points
        profile.updatedAt = row.updatedAt
        profile.deletedAt = row.deletedAt
        profile.isDirty = false

        let seeded = ProgressFactory.makeInitialProgress()
        for pp in seeded {
            pp.isDirty = false
            pp.updatedAt = .distantPast
            for stage in pp.stages {
                stage.isDirty = false
                stage.updatedAt = .distantPast
            }
        }
        profile.phonemeProgress = seeded
        return profile
    }

    private func makePhonemeProgress(from row: PhonemeProgressRow, child: ChildProfile) -> PhonemeProgress {
        let pp = PhonemeProgress(phonemeCode: row.phonemeCode,
                                 status: ProgressStatus(rawValue: row.status) ?? .locked)
        pp.id = row.id
        pp.completionCount = row.completionCount
        pp.updatedAt = row.updatedAt
        pp.deletedAt = row.deletedAt
        pp.isDirty = false
        pp.child = child
        return pp
    }

    private func makeStageProgress(from row: StageProgressRow, parent: PhonemeProgress) -> StageProgress {
        let sp = StageProgress(stage: LearningStage(rawValue: row.stage) ?? .palabras,
                               status: ProgressStatus(rawValue: row.status) ?? .locked,
                               itemsCompleted: row.itemsCompleted)
        sp.id = row.id
        sp.lastPracticedAt = row.lastPracticedAt
        sp.updatedAt = row.updatedAt
        sp.deletedAt = row.deletedAt
        sp.isDirty = false
        sp.phonemeProgress = parent
        return sp
    }

    // MARK: - Helpers

    private static func key(_ childId: UUID, _ phonemeCode: String) -> String {
        "\(childId.uuidString)|\(phonemeCode)"
    }
    private static func key(_ childId: UUID, _ phonemeCode: String, _ stage: String) -> String {
        "\(childId.uuidString)|\(phonemeCode)|\(stage)"
    }

    private static func friendlyMessage(for error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("offline") || text.contains("network") || text.contains("connection")
            || text.contains("internet") || text.contains("timed out") {
            return "Sin conexión. La app sigue funcionando local."
        }
        if text.contains("jwt") || text.contains("unauthorized") || text.contains("permission") {
            return "Tu sesión expiró. Inicia sesión de nuevo."
        }
        return "No se pudo sincronizar. Inténtalo más tarde."
    }
}

// MARK: - DTOs (mapeo 1:1 con las tablas; claves snake_case exactas)

/// Tabla `children`. `name` es alias/apodo; NO se sube nada sensible ni audio.
private struct ChildRow: Codable {
    let id: UUID
    let parentId: UUID
    let name: String
    let ageBand: String
    let avatarKey: String
    let points: Int
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case parentId = "parent_id"
        case name
        case ageBand = "age_band"
        case avatarKey = "avatar_key"
        case points
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(from profile: ChildProfile, parentId: UUID) {
        self.id = profile.id
        self.parentId = parentId
        self.name = profile.name
        self.ageBand = profile.ageBandRaw
        self.avatarKey = profile.avatarKey
        self.points = profile.points
        self.updatedAt = profile.updatedAt
        self.deletedAt = profile.deletedAt
    }
}

/// Tabla `phoneme_progress`. Unique (child_id, phoneme_code). Solo progreso, sin audio.
private struct PhonemeProgressRow: Codable {
    let id: UUID
    let childId: UUID
    let phonemeCode: String
    let status: String
    let completionCount: Int
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case phonemeCode = "phoneme_code"
        case status
        case completionCount = "completion_count"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init?(from pp: PhonemeProgress) {
        guard let childId = pp.child?.id else { return nil }
        self.id = pp.id
        self.childId = childId
        self.phonemeCode = pp.phonemeCode
        self.status = pp.statusRaw
        self.completionCount = pp.completionCount
        self.updatedAt = pp.updatedAt
        self.deletedAt = pp.deletedAt
    }
}

/// Tabla `stage_progress`. Unique (child_id, phoneme_code, stage). Solo progreso.
private struct StageProgressRow: Codable {
    let id: UUID
    let childId: UUID
    let phonemeCode: String
    let stage: String
    let status: String
    let itemsCompleted: Int
    let lastPracticedAt: Date?
    let updatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case phonemeCode = "phoneme_code"
        case stage
        case status
        case itemsCompleted = "items_completed"
        case lastPracticedAt = "last_practiced_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init?(from sp: StageProgress) {
        guard let pp = sp.phonemeProgress, let childId = pp.child?.id else { return nil }
        self.id = sp.id
        self.childId = childId
        self.phonemeCode = pp.phonemeCode
        self.stage = sp.stageRaw
        self.status = sp.statusRaw
        self.itemsCompleted = sp.itemsCompleted
        self.lastPracticedAt = sp.lastPracticedAt
        self.updatedAt = sp.updatedAt
        self.deletedAt = sp.deletedAt
    }
}

/// Tabla `speech_attempts` (append-only). SOLO métricas educativas seguras.
/// ⚠️ Privacidad: NO incluye `rawTranscription`, texto crudo de STT, audio ni nada
/// sensible. `created_at` = `timestamp` del intento (inmutable). Sin `updated_at`
/// ni `deleted_at`: el registro no se actualiza ni se borra.
private struct SpeechAttemptRow: Codable {
    let id: UUID
    let childId: UUID
    let targetPhoneme: String
    let targetWord: String
    let stage: String
    let algorithmPassed: Bool
    let similarityScore: Double
    let thresholdUsed: Double
    let humanJudgment: String
    let durationMs: Int
    let recognizerLocale: String
    let onDevice: Bool
    let childAgeBand: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case targetPhoneme = "target_phoneme"
        case targetWord = "target_word"
        case stage
        case algorithmPassed = "algorithm_passed"
        case similarityScore = "similarity_score"
        case thresholdUsed = "threshold_used"
        case humanJudgment = "human_judgment"
        case durationMs = "duration_ms"
        case recognizerLocale = "recognizer_locale"
        case onDevice = "on_device"
        case childAgeBand = "child_age_band"
        case createdAt = "created_at"
    }

    init?(from a: SpeechAttempt) {
        guard let childId = a.child?.id else { return nil }
        self.id = a.id
        self.childId = childId
        self.targetPhoneme = a.targetPhoneme
        self.targetWord = a.targetWord
        self.stage = a.stage
        self.algorithmPassed = a.algorithmPassed
        self.similarityScore = a.similarityScore
        self.thresholdUsed = a.thresholdUsed
        self.humanJudgment = a.humanJudgment
        self.durationMs = a.durationMs
        self.recognizerLocale = a.recognizerLocale
        self.onDevice = a.onDevice
        self.childAgeBand = a.childAgeBand
        self.createdAt = a.timestamp
        // NOTA: `a.rawTranscription` existe local pero NO se mapea: nunca se sube.
    }
}
