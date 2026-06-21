import Foundation

/// Ajustes SOLO para pruebas del MVP. No es una opción visible para el niño:
/// es una constante de compilación que cambia el desarrollador.
///
/// `isDeveloperModeEnabled`: si está activo, todos los fonemas aparecen
/// desbloqueados desde el inicio para poder probarlos sin avance secuencial.
/// NO elimina el sistema de progreso/desbloqueo: solo evita el candado en la UI;
/// el progreso por palabras correctas se sigue registrando igual.
enum DeveloperSettings {
    static let isDeveloperModeEnabled = true
}
