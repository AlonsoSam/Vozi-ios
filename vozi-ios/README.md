# VOZI iOS

**VOZI** es una app educativa iOS para niños de **4 a 7 años** que apoya la práctica y refuerzo de la pronunciación.

No es una app médica, clínica ni de diagnóstico: su enfoque es educativo, lúdico y de acompañamiento.

## Qué hace

El niño elige un fonema o grupo y practica **palabras**. Cada palabra muestra:

* una imagen de apoyo;
* la palabra escrita;
* botón **Escuchar** (audio modelo: `.mp3` personalizado por palabra si existe, con TTS del sistema como respaldo);
* botón **Hablar** (reconocimiento de voz on-device);
* feedback educativo positivo.

La aprobación combina la palabra exacta normalizada, la regla del fonema/grupo y la similitud como apoyo; no depende de un juez clínico.

Incluye además:

* progreso local (offline);
* perfiles de niño con subperfil por edad;
* sección de adulto (PIN) para revisar progreso e intentos, con juicio adulto como apoyo;
* gamificación: puntos y recompensas;
* skins/personajes coleccionables con animaciones **Rive** en "Mis recompensas";
* audios personalizados (Fase 5): `.mp3` por palabra para Escuchar y frases de audio aleatorias de acierto, fallo y fin de sesión (TTS como fallback; STT y evaluación sin cambios).

Privacidad: no se guarda ni se sube audio crudo del niño.

## Tecnologías

* SwiftUI · SwiftData · Speech Framework · AVFoundation
* XcodeGen (generación del proyecto)
* RiveRuntime (animaciones de recompensas)

## Generar y abrir el proyecto

El proyecto se genera con **XcodeGen** (no se versiona el `.xcodeproj`).

```bash
cd vozi-ios
xcodegen generate
open VoziIOS.xcodeproj
```

Luego ejecuta la app desde Xcode en un simulador. La primera vez, Xcode resolverá la dependencia **RiveRuntime** por Swift Package Manager.

Build desde la línea de comandos (Xcode completo):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project VoziIOS.xcodeproj -scheme VoziIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Roadmap

* Premium / pago simulado (solo simulación para demostración; sin cobro real).
* Supabase como backend común (perfiles, progreso, puntos, recompensas e intentos) para escalar a iOS y Android.
* App Android en Flutter conectada a Supabase.
