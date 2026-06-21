import Foundation

/// Resultado de evaluar una PALABRA con criterio por fonema.
struct WordMatchResult {
    let score: Double      // similitud normalizada 0...1 (apoyo, no juez único)
    let passed: Bool       // aprobado: similitud suficiente Y se conserva el sonido
    let phonemeOk: Bool    // true si el sonido objetivo se conservó en lo reconocido
}

/// Evaluación de palabras del MVP con reglas por fonema (Fase 2 reenfocada).
///
/// Criterio de aprobación (todas obligatorias salvo la similitud, que es apoyo):
///  1. La palabra objetivo normalizada aparece como TOKEN COMPLETO en la
///     transcripción normalizada (no basta parecerse). Así:
///       - "rama" ≠ "rana", "rueda" ≠ "ruda", "rana" ≠ "ana", "ropa" ≠ "opa".
///       - "reloj" ✓ en "el reloj", "rana" ✓ en "la rana".
///  2. Se conserva el sonido del fonema trabajado:
///       - R/S/L iniciales: el token objetivo empieza con esa letra.
///       - RR: conserva el grupo "rr" ("perro" ≠ "pero", "carro" ≠ "caro").
///       - TR: conserva el grupo "tr".
///  3. Similitud normalizada ≥ 0.8 como APOYO/respaldo; nunca aprueba si la
///     palabra exacta no aparece (la regla 1 manda).
///
/// La similitud no es juez único. STT base on-device; sin lenguaje clínico.
enum PhonemeWordEvaluator {

    /// Similitud mínima de respaldo. La aprobación real depende del token exacto.
    private static let supportSimilarity = 0.8

    static func evaluate(phoneme: Phoneme, target: String,
                         transcription: String, threshold: Double) -> WordMatchResult {
        let nt = ApproximateMatcher.normalize(target)
        let tokens = ApproximateMatcher.normalize(transcription)
            .split(separator: " ").map(String.init)

        let exact = tokens.contains(nt)                       // regla 1
        let phonemeOk = soundPreserved(phoneme: phoneme, targetNormalized: nt)  // regla 2
        let score = ApproximateMatcher.similarity(target: target, transcription: transcription)

        let passed = exact && phonemeOk && score >= supportSimilarity  // regla 3 (apoyo)
        return WordMatchResult(score: score, passed: passed, phonemeOk: phonemeOk)
    }

    // MARK: - Privados

    /// ¿El token objetivo conserva el sonido del fonema trabajado?
    private static func soundPreserved(phoneme: Phoneme, targetNormalized nt: String) -> Bool {
        switch phoneme {
        case .rr: return nt.contains("rr")        // doble R
        case .tr: return nt.contains("tr")        // grupo TR
        case .pr: return nt.contains("pr")        // grupo PR
        case .pl: return nt.contains("pl")        // grupo PL
        case .br: return nt.contains("br")        // grupo BR
        case .bl: return nt.contains("bl")        // grupo BL
        case .r:  return nt.hasPrefix("r")        // R inicial
        case .s:  return nt.hasPrefix("s")        // S inicial
        case .l:  return nt.hasPrefix("l")        // L inicial
        }
    }
}
