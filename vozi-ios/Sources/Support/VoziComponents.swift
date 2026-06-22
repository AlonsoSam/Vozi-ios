import SwiftUI

/// Componentes de UI reutilizables de VOZI (Fase 6.5 — rediseño UI/UX).
///
/// Aquí vive el "kit" visual compartido por todas las pantallas para mantener un
/// look infantil, limpio y consistente: header hero, pills de estadística, chips
/// de estado, barra de progreso, secciones de adulto y avatar. Solo presentación;
/// no contiene lógica de evaluación, progreso, gamificación ni datos.

// MARK: - Estados visuales unificados

/// Catálogo único de estados visuales de la app. Centralizar color + icono + texto
/// evita que cada pantalla invente su propia variante. Solo describe apariencia.
enum VoziStatus {
    case available          // disponible para practicar
    case lockedProgress     // bloqueado por progreso (candado gris)
    case lockedPremium      // bloqueado por Premium (corona dorada)
    case completed          // fonema/etapa completada
    case rewardUnlocked     // recompensa desbloqueada
    case rewardLocked       // recompensa por desbloquear
    case success            // acierto en la práctica
    case almost             // "casi", sigue practicando
    case premiumActive      // Premium simulado activo
    case premiumInactive    // Premium simulado inactivo

    var color: Color {
        switch self {
        case .available:       return VoziTheme.brand
        case .lockedProgress:  return VoziTheme.neutral
        case .lockedPremium:   return VoziTheme.sunshine
        case .completed:       return VoziTheme.success
        case .rewardUnlocked:  return VoziTheme.success
        case .rewardLocked:    return VoziTheme.neutral
        case .success:         return VoziTheme.success
        case .almost:          return VoziTheme.almost
        case .premiumActive:   return VoziTheme.sunshine
        case .premiumInactive: return VoziTheme.neutral
        }
    }

    var icon: String {
        switch self {
        case .available:       return "play.circle.fill"
        case .lockedProgress:  return "lock.fill"
        case .lockedPremium:   return "crown.fill"
        case .completed:       return "checkmark.circle.fill"
        case .rewardUnlocked:  return "sparkles"
        case .rewardLocked:    return "lock.fill"
        case .success:         return "star.circle.fill"
        case .almost:          return "hand.thumbsup.circle.fill"
        case .premiumActive:   return "checkmark.seal.fill"
        case .premiumInactive: return "crown"
        }
    }

    var label: String {
        switch self {
        case .available:       return "Disponible"
        case .lockedProgress:  return "Bloqueado"
        case .lockedPremium:   return "Premium"
        case .completed:       return "Completado"
        case .rewardUnlocked:  return "¡Desbloqueado!"
        case .rewardLocked:    return "Por desbloquear"
        case .success:         return "¡Muy bien!"
        case .almost:          return "¡Casi!"
        case .premiumActive:   return "Premium activo"
        case .premiumInactive: return "Premium inactivo"
        }
    }
}

// MARK: - Chip de estado (pill con icono + texto)

/// Pill compacta que comunica un estado con icono + texto. Reutilizable en tiles,
/// recompensas y panel adulto para unificar la lectura de estados.
struct VoziStatusChip: View {
    let status: VoziStatus
    var compact: Bool = false

    var body: some View {
        Label {
            if !compact { Text(status.label) }
        } icon: {
            Image(systemName: status.icon)
        }
        .font(.vozi(.caption, weight: .bold))
        .foregroundStyle(status.color)
        .padding(.vertical, compact ? 6 : 6)
        .padding(.horizontal, compact ? 8 : 12)
        .background(status.color.opacity(0.16), in: Capsule())
    }
}

// MARK: - Insignia circular de icono (badge sobre íconos)

/// Pequeña insignia circular con fondo blanco, para superponer un estado sobre un
/// icono grande (p. ej. esquina de un tile).
struct VoziIconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .padding(4)
            .background(Circle().fill(VoziTheme.cardFill))
            .shadow(color: VoziTheme.Shadow.soft, radius: 3, x: 0, y: 1)
    }
}

// MARK: - Icono hero (círculo con degradado)

/// Círculo grande con degradado y un SF Symbol al centro. Base de los headers hero.
struct VoziHeroIcon: View {
    let symbol: String
    var gradient: LinearGradient
    var size: CGFloat = 92

    init(symbol: String, color: Color, size: CGFloat = 92) {
        self.symbol = symbol
        self.gradient = VoziTheme.gradient(color)
        self.size = size
        self.shadowColor = color
    }

    init(symbol: String, gradient: LinearGradient, shadowColor: Color, size: CGFloat = 92) {
        self.symbol = symbol
        self.gradient = gradient
        self.size = size
        self.shadowColor = shadowColor
    }

    private let shadowColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient)
                .frame(width: size, height: size)
                .shadow(color: shadowColor.opacity(0.40), radius: 10, x: 0, y: 6)
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Header hero reutilizable

/// Encabezado tipo "hero": icono circular grande + título + subtítulo, centrado.
/// Da identidad a las pantallas para que no parezcan listas genéricas de iOS.
struct VoziHero: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var color: Color = VoziTheme.brand

    var body: some View {
        VStack(spacing: VoziTheme.Space.md) {
            VoziHeroIcon(symbol: symbol, color: color)
            Text(title)
                .font(.vozi(.title2, weight: .bold))
                .foregroundStyle(VoziTheme.ink)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.vozi(.subheadline))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pill de estadística

/// Pill de estadística con icono + valor (puntos, personajes, intentos…).
struct VoziStatPill: View {
    let symbol: String
    let text: String
    var color: Color = VoziTheme.brand

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.vozi(.headline))
            .foregroundStyle(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(color.opacity(0.16), in: Capsule())
    }
}

// MARK: - Barra de progreso VOZI

/// Barra de progreso redondeada con relleno del color dado. Presentación pura.
struct VoziProgressBar: View {
    /// 0...1
    let value: Double
    var color: Color = VoziTheme.brand
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule()
                    .fill(VoziTheme.gradient(color))
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Sección visual (para zonas de adulto)

/// Tarjeta de sección con título + icono opcional, para que las pantallas de adulto
/// se vean como VOZI y no como un `Form` genérico de iOS.
struct VoziSection<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var color: Color = VoziTheme.brand
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: VoziTheme.Space.md) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.vozi(.subheadline, weight: .bold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.vozi(.headline))
                    .foregroundStyle(VoziTheme.ink)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VoziTheme.Space.lg)
        .voziCard()
    }
}

// MARK: - Estado vacío VOZI

/// Estado vacío amigable y de marca (icono hero + mensaje + acción opcional).
struct VoziEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var color: Color = VoziTheme.brand
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: VoziTheme.Space.lg) {
            VoziHeroIcon(symbol: symbol, color: color, size: 96)
            VStack(spacing: VoziTheme.Space.sm) {
                Text(title)
                    .font(.vozi(.title3, weight: .bold))
                    .foregroundStyle(VoziTheme.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.vozi(.subheadline))
                    .foregroundStyle(VoziTheme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(VoziBigButtonStyle(fill: color))
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(VoziTheme.Space.xl)
        .frame(maxWidth: 420)
    }
}
