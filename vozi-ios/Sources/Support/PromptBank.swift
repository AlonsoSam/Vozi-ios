import Foundation

/// Banco mínimo de prueba para Fase 0 (solo R/S/L; NO los 8 fonemas).
/// `all` es estático para que las instancias tengan identidad estable
/// (necesario para la selección en los Picker de SwiftUI).
enum PromptBank {
    static let phonemes = ["R", "S", "L"]

    static let all: [TestPrompt] = [
        // R
        TestPrompt(phoneme: "R", word: "ra",     stage: .silabas),
        TestPrompt(phoneme: "R", word: "ri",     stage: .silabas),
        TestPrompt(phoneme: "R", word: "rosa",   stage: .palabras),
        TestPrompt(phoneme: "R", word: "ratón",  stage: .palabras),
        TestPrompt(phoneme: "R", word: "perro",  stage: .palabras),
        // S
        TestPrompt(phoneme: "S", word: "sa",     stage: .silabas),
        TestPrompt(phoneme: "S", word: "sol",    stage: .palabras),
        TestPrompt(phoneme: "S", word: "sapo",   stage: .palabras),
        TestPrompt(phoneme: "S", word: "casa",   stage: .palabras),
        // L
        TestPrompt(phoneme: "L", word: "la",     stage: .silabas),
        TestPrompt(phoneme: "L", word: "luna",   stage: .palabras),
        TestPrompt(phoneme: "L", word: "lápiz",  stage: .palabras),
        TestPrompt(phoneme: "L", word: "pelota", stage: .palabras),
    ]

    static func prompts(for phoneme: String) -> [TestPrompt] {
        all.filter { $0.phoneme == phoneme }
    }
}
