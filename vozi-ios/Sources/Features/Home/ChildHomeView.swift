import SwiftUI
import SwiftData

/// Home del niño: grid de los 5 fonemas del MVP con su estado (disponible /
/// bloqueado / completado). Tocar un fonema disponible abre su detalle de etapas.
/// Texto mínimo y botones grandes (spec §11).
struct ChildHomeView: View {
    let profile: ChildProfile

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 20)]

    /// Progreso de fonemas ordenado pedagógicamente (R, RR, S, L, TR).
    private var orderedProgress: [PhonemeProgress] {
        profile.phonemeProgress.sorted { ($0.phoneme?.order ?? .max) < ($1.phoneme?.order ?? .max) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(orderedProgress) { progress in
                    tile(for: progress)
                }
            }
            .padding(20)
        }
        .navigationTitle("¡Hola, \(profile.name)!")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PhonemeProgress.self) { progress in
            PhonemeDetailView(progress: progress)
        }
    }

    @ViewBuilder
    private func tile(for progress: PhonemeProgress) -> some View {
        if progress.status == .locked {
            PhonemeTile(progress: progress)            // bloqueado: no navega
        } else {
            NavigationLink(value: progress) {
                PhonemeTile(progress: progress)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Tarjeta grande de un fonema con icono y estado.
private struct PhonemeTile: View {
    let progress: PhonemeProgress

    var body: some View {
        let phoneme = progress.phoneme
        let locked = progress.status == .locked
        let completed = progress.status == .completed

        VStack(spacing: 12) {
            Image(systemName: phoneme?.iconSystemName ?? "questionmark")
                .font(.system(size: 44))
                .foregroundStyle(locked ? Color.secondary : .accentColor)
                .frame(width: 96, height: 96)
                .background(Color.accentColor.opacity(locked ? 0.06 : 0.15), in: Circle())
                .overlay(alignment: .bottomTrailing) { statusBadge(locked: locked, completed: completed) }
            Text(phoneme?.displayName ?? "—")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .opacity(locked ? 0.6 : 1)
        .accessibilityLabel(accessibilityText(phoneme: phoneme, locked: locked, completed: completed))
    }

    @ViewBuilder
    private func statusBadge(locked: Bool, completed: Bool) -> some View {
        if locked {
            badgeIcon("lock.fill", .secondary)
        } else if completed {
            badgeIcon("checkmark.circle.fill", .green)
        }
    }

    private func badgeIcon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
            .background(Circle().fill(.background))
    }

    private func accessibilityText(phoneme: Phoneme?, locked: Bool, completed: Bool) -> String {
        let name = phoneme?.displayName ?? ""
        if locked { return "Fonema \(name), bloqueado" }
        if completed { return "Fonema \(name), completado" }
        return "Fonema \(name), disponible"
    }
}
