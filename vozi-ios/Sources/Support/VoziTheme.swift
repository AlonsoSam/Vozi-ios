import SwiftUI

/// Sistema de diseño de VOZI (Fase 3B): paleta infantil, fondo, color por
/// fonema/grupo y estilos reutilizables (tarjetas y botones grandes).
///
/// Todos los colores se definen en código (no se toca `Media.xcassets`). El tono
/// es cálido y alegre, con texto oscuro de buen contraste para lectura clara.
enum VoziTheme {

    // MARK: - Paleta

    static let coral     = Color(red: 1.00, green: 0.45, blue: 0.45)
    static let peach     = Color(red: 1.00, green: 0.62, blue: 0.42)
    static let sunshine  = Color(red: 1.00, green: 0.78, blue: 0.30)
    static let sky       = Color(red: 0.35, green: 0.66, blue: 0.96)
    static let mint      = Color(red: 0.30, green: 0.80, blue: 0.64)
    static let lavender  = Color(red: 0.68, green: 0.56, blue: 0.94)
    static let bubblegum = Color(red: 0.97, green: 0.50, blue: 0.74)
    static let teal      = Color(red: 0.20, green: 0.74, blue: 0.78)
    static let grape     = Color(red: 0.55, green: 0.46, blue: 0.92)

    /// Verde/naranja de feedback (acierto / "casi").
    static let success = Color(red: 0.26, green: 0.74, blue: 0.45)
    static let almost  = Color(red: 1.00, green: 0.62, blue: 0.27)

    // MARK: - Fondo

    /// Fondo amigable: degradado pastel muy suave. Se coloca detrás de la pantalla.
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.92, green: 0.97, blue: 1.00),
                Color(red: 0.97, green: 0.94, blue: 1.00),
                Color(red: 1.00, green: 0.96, blue: 0.93)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Color por fonema/grupo

    /// Identidad visual de cada fonema/grupo del MVP. Solo presentación; no afecta
    /// la evaluación ni el banco de palabras.
    static func color(for phoneme: Phoneme) -> Color {
        switch phoneme {
        case .r:  return coral
        case .rr: return peach
        case .s:  return sunshine
        case .l:  return sky
        case .tr: return mint
        case .pr: return lavender
        case .pl: return bubblegum
        case .br: return teal
        case .bl: return grape
        }
    }

    /// Conveniencia desde el código del fonema persistido.
    static func color(forCode code: String) -> Color {
        Phoneme(rawValue: code).map(color(for:)) ?? sky
    }
}

// MARK: - Tarjeta reutilizable

extension View {
    /// Tarjeta infantil: fondo claro, esquinas muy redondeadas y sombra suave.
    func voziCard(cornerRadius: CGFloat = 24,
                  fill: some ShapeStyle = Color(.secondarySystemBackground),
                  shadow: Color = .black.opacity(0.10)) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: shadow, radius: 12, x: 0, y: 6)
    }
}

// MARK: - Estilos de botón

/// Botón grande "chunky" para acciones primarias infantiles (color + sombra +
/// rebote al presionar).
struct VoziBigButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: fill.opacity(0.40), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Botón tonal (relleno suave del color) para acciones secundarias como Escuchar.
struct VoziTonalButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(tint.opacity(0.16), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Rebote sutil al presionar, para tarjetas tappables (Home).
struct VoziPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
