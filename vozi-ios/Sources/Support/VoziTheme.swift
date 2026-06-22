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

    // MARK: - Colores semánticos (modo claro)

    /// VOZI prioriza el aspecto claro: estos colores fijan tinta y superficies para
    /// que la jerarquía y el contraste sean estables sin depender del modo del sistema.

    /// Color principal de marca (acentos, links, controles).
    static let brand = sky
    /// Tinta de texto principal: azul muy oscuro, más cálido que negro puro.
    static let ink     = Color(red: 0.16, green: 0.20, blue: 0.33)
    /// Tinta secundaria para subtítulos y descripciones.
    static let inkSoft = Color(red: 0.42, green: 0.46, blue: 0.56)
    /// Relleno de tarjetas (superficie elevada sobre el fondo pastel).
    static let cardFill = Color.white
    /// Relleno neutro para estados bloqueados por progreso.
    static let neutral = Color(red: 0.62, green: 0.65, blue: 0.72)

    // MARK: - Tokens de diseño

    /// Espaciados base (múltiplos suaves) para mantener ritmo entre pantallas.
    enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 30
        static let xxl: CGFloat = 40
    }

    /// Radios de esquina consistentes.
    enum Radius {
        static let sm: CGFloat = 14
        static let md: CGFloat = 20
        static let lg: CGFloat = 26
        static let xl: CGFloat = 32
    }

    /// Sombras suaves reutilizables.
    enum Shadow {
        static let soft = Color.black.opacity(0.06)
        static let card = Color.black.opacity(0.08)
        static let lifted = Color.black.opacity(0.12)
    }

    // MARK: - Fondo

    /// Fondo amigable: degradado pastel muy suave. Se coloca detrás de la pantalla.
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.97, blue: 1.00),
                Color(red: 0.97, green: 0.95, blue: 1.00),
                Color(red: 1.00, green: 0.97, blue: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Degradado de marca para íconos hero y acentos circulares.
    static func gradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color, color.opacity(0.72)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Degradado cálido reservado para Premium (corona).
    static var premiumGradient: LinearGradient {
        LinearGradient(colors: [sunshine, peach],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
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
    /// Tarjeta infantil: superficie blanca, esquinas muy redondeadas y sombra suave.
    func voziCard(cornerRadius: CGFloat = VoziTheme.Radius.lg,
                  fill: some ShapeStyle = VoziTheme.cardFill,
                  shadow: Color = VoziTheme.Shadow.card) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: shadow, radius: 14, x: 0, y: 8)
    }

    /// Aplica el fondo VOZI a pantalla completa (degradado pastel claro).
    func voziBackground() -> some View {
        background(VoziTheme.background.ignoresSafeArea())
    }
}

// MARK: - Tipografía (SF Rounded)

extension Font {
    /// Fuente redondeada VOZI a partir de un estilo de texto del sistema (Dynamic Type).
    static func vozi(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
    /// Fuente redondeada VOZI de tamaño fijo (para títulos hero o números grandes).
    static func vozi(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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
            .font(.vozi(.title3, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                VoziTheme.gradient(fill),
                in: RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous)
            )
            .shadow(color: fill.opacity(0.38), radius: 12, x: 0, y: 7)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Botón secundario "outline": fondo claro con borde del color. Para acciones
/// alternativas (Cancelar, Desactivar) que no deben competir con la primaria.
struct VoziSecondaryButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.vozi(.title3, weight: .bold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VoziTheme.Radius.md, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Botón tonal (relleno suave del color) para acciones secundarias como Escuchar.
struct VoziTonalButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.vozi(.headline))
            .foregroundStyle(tint)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(tint.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1))
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
