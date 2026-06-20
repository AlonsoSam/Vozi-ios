import Foundation

struct MatchResult {
    let score: Double   // 0...1
    let passed: Bool
}

/// Comparación por aproximación tolerante (spec §10).
///
/// NOTA: este cálculo es TEMPORAL y vive en el cliente solo para la Fase 0.
/// En Fase 1+ la lógica sensible (umbral definitivo) migrará a Edge Functions.
/// Por eso queda aislado en su propio archivo.
enum ApproximateMatcher {

    /// minúsculas, sin tildes, sin puntuación, espacios colapsados.
    static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Similitud 0...1 basada en distancia de edición, con refuerzo por
    /// "contiene" (la transcripción suele traer palabras extra).
    static func similarity(target: String, transcription: String) -> Double {
        let t = normalize(target)
        let r = normalize(transcription)
        guard !t.isEmpty else { return 0 }
        if r.isEmpty { return 0 }

        // Coincidencia exacta como subcadena de palabra completa.
        let words = r.split(separator: " ").map(String.init)
        if words.contains(t) { return 1.0 }

        // Mejor similitud contra cada palabra de la transcripción.
        let perWord = words.map { word -> Double in
            sim(Array(t), Array(word))
        }.max() ?? 0

        // Similitud contra la cadena completa.
        let full = sim(Array(t), Array(r))

        return max(perWord, full)
    }

    static func evaluate(target: String, transcription: String, threshold: Double) -> MatchResult {
        let score = similarity(target: target, transcription: transcription)
        return MatchResult(score: score, passed: score >= threshold)
    }

    // MARK: - Privados

    private static func sim(_ a: [Character], _ b: [Character]) -> Double {
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1 }
        let d = levenshtein(a, b)
        return 1 - Double(d) / Double(maxLen)
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1,        // borrado
                              curr[j - 1] + 1,    // inserción
                              prev[j - 1] + cost) // sustitución
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
