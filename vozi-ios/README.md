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
