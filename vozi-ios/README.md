# VOZI iOS

Aplicación iOS desarrollada en SwiftUI para validar el reconocimiento de voz de VOZI.

## Estado actual

Fase 0: validación técnica de Speech-to-Text.

Esta versión permite:

- solicitar permisos de micrófono y reconocimiento de voz;
- seleccionar una palabra objetivo;
- grabar la voz del usuario;
- transcribir audio con Speech Framework;
- comparar la transcripción con la palabra objetivo usando similitud aproximada;
- guardar intentos localmente con SwiftData;
- revisar resultados y exportar datos en CSV.

## Importante

Esta versión no es la interfaz infantil final.  
Es una herramienta de prueba operada por un adulto para validar el funcionamiento base del reconocimiento de voz.

## Tecnologías

- SwiftUI
- SwiftData
- Speech Framework
- AVFoundation
- MVVM

## Privacidad

VOZI no guarda audio crudo.  
La app almacena texto reconocido y métricas de prueba para análisis.

## Generar proyecto Xcode

Este proyecto usa XcodeGen.

## Estado actual

Fase 1 completada: app educativa base en iOS.

Esta versión permite:

* crear y administrar perfiles de niño;
* seleccionar edad y avatar;
* practicar los fonemas MVP: R, RR, S, L y TR;
* avanzar por etapas: Escuchar, Sílabas, Palabras, Frases y Misión;
* reproducir audio modelo con TTS del sistema;
* practicar con reconocimiento de voz usando STT on-device;
* guardar intentos y progreso localmente con SwiftData;
* desbloquear etapas y fonemas de forma progresiva;
* acceder a una zona de adultos protegida con PIN local;
* revisar progreso e intentos;
* registrar juicio adulto;
* exportar resultados en CSV;
* mantener accesible el Spike STT de Fase 0.

## Limitaciones detectadas

El STT base sirve como coincidencia aproximada de palabra, pero no como evaluación fina de pronunciación. En pruebas, algunas sílabas pueden transcribirse de forma incorrecta, por ejemplo “sa” como “ya”.

El TTS del sistema puede leer algunas sílabas como letras separadas, por ejemplo “rra”. En una fase posterior se evaluará el uso de audios grabados o una tecnología especializada como Azure Pronunciation Assessment.

## Privacidad

VOZI no guarda audio crudo.
La app almacena texto reconocido, progreso, intentos y métricas educativas de práctica.
