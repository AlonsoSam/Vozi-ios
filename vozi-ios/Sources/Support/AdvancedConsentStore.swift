import Foundation

/// Consentimiento del adulto para la evaluación avanzada (Azure).
///
/// APAGADO por defecto (privacidad, spec §6/§7): si el adulto no lo activa, la
/// app NO ofrece Azure al niño y todo usa el modo base (Apple on-device).
///
/// Aquí vive solo el almacenamiento. La UI para activarlo (panel de adultos, con
/// la explicación de que es educativo/referencial y que no se guarda audio crudo)
/// se añade en el BLOQUE 2C.
enum AdvancedConsentStore {
    /// Clave de UserDefaults. Pública para enlazar la UI con `@AppStorage` sin
    /// duplicar el literal (panel de adultos, BLOQUE 2C).
    static let defaultsKey = "vozi.advancedEvaluationConsent"

    /// Interruptor maestro de la evaluación avanzada (Azure).
    ///
    /// MVP reenfocado (Fase 2): la evaluación principal es por PALABRAS con STT
    /// base on-device. Azure quedó como EXPERIMENTAL y DESACTIVADO porque no
    /// devolvía puntajes útiles en pruebas reales. Mientras esté en `false`, el
    /// flujo nunca usa Azure aunque el adulto active el consentimiento.
    static let featureEnabled = false

    static var isGranted: Bool {
        get { UserDefaults.standard.bool(forKey: defaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }
}
