# VOZI iOS

Aplicación iOS desarrollada en SwiftUI para el refuerzo educativo de pronunciación en niños de 4 a 7 años.

VOZI permite practicar palabras organizadas por fonemas y grupos consonánticos, usando imágenes, audio modelo y reconocimiento de voz local como apoyo. La app no realiza diagnóstico clínico ni reemplaza la orientación de un especialista; su enfoque es educativo, lúdico y de acompañamiento.

## Estado actual

MVP funcional en iOS enfocado en práctica de palabras.

El flujo principal actual es:

1. El niño selecciona un fonema o grupo consonántico.
2. La app entra directamente a la práctica de palabras.
3. Cada palabra muestra:

   * imagen;
   * palabra escrita;
   * botón **Escuchar** para reproducir el modelo con TTS;
   * botón **Hablar** para practicar con reconocimiento de voz;
   * feedback educativo.
4. El progreso se guarda localmente.
5. El adulto puede revisar intentos, registrar juicio adulto y exportar resultados en CSV.

## Fonemas y grupos trabajados

El MVP actual trabaja con 9 fonemas/grupos:

* R
* RR
* S
* L
* TR
* PR
* PL
* BR
* BL

Estos 9 grupos también están pensados para conectarse más adelante con un sistema de recompensas, skins o personajes coleccionables.

## Banco actual de palabras

### R

* rana
* rosa
* ratón
* reloj
* rueda
* rama
* regalo
* río
* ropa
* radio

### RR

* perro
* carro
* torre
* burro
* gorra
* jarra
* tierra
* barro
* parra
* cerro

### S

* sapo
* sol
* silla
* sopa
* sandía
* saco
* semilla
* sombrero
* serpiente
* sirena

### L

* luna
* lápiz
* loro
* leche
* lámpara
* libro
* limón
* llave
* lobo
* lata

### TR

* tren
* trapo
* trono
* trigo
* trompo
* tres
* trozo
* trucha
* trenza
* trofeo

### PR

* proa
* presa
* prisa
* prado
* prenda
* pradera
* prendedor
* prensa
* pronto
* promesa

### PL

* plato
* pluma
* playa
* plaza
* pleno
* pliego
* plancha
* plano
* plaga
* plomo

### BR

* brazo
* brisa
* brocha
* brasa
* bravo
* brillo
* broma
* cebra
* libro
* cabra

### BL

* blanco
* blusa
* bloque
* blando
* cable
* tabla
* pueblo
* mueble
* ombligo
* establo

## Evaluación

El MVP usa reconocimiento de voz local mediante Apple Speech Framework.

La aprobación de una palabra no depende solo de similitud aproximada. El criterio principal es:

1. normalizar la palabra objetivo y la transcripción;
2. verificar que la palabra objetivo aparezca como palabra completa dentro de la transcripción;
3. validar la regla del fonema o grupo trabajado;
4. usar la similitud como dato de apoyo para análisis y CSV.

Ejemplos:

* `rana` no aprueba si se reconoce `ana`;
* `perro` no aprueba si se reconoce `pero`;
* `carro` no aprueba si se reconoce `caro`;
* `plato` no aprueba si se reconoce `pato`;
* `blanco` no aprueba si se reconoce `banco`.

## Imágenes

Las imágenes de las palabras se almacenan en:

```text
Media.xcassets
```

El formato de nombre usado es:

```text
word_<palabra_normalizada>
```

Ejemplos:

```text
word_rana
word_raton
word_lapiz
word_platano
word_tierra
word_prendedor
```

Las tildes se eliminan en el nombre del asset.

## Panel adulto

La app incluye una zona de adultos con PIN local. Desde ahí se puede:

* revisar el progreso;
* revisar intentos realizados;
* registrar juicio adulto;
* exportar resultados en CSV.

El juicio adulto se mantiene como apoyo, especialmente porque los motores STT pueden autocorregir algunas palabras.

## Privacidad

VOZI no guarda audio crudo.

La app almacena localmente:

* texto reconocido;
* palabra objetivo;
* fonema o grupo trabajado;
* resultado del intento;
* progreso;
* juicio adulto;
* métricas educativas para análisis.

## Tecnologías

* SwiftUI
* SwiftData
* Apple Speech Framework
* AVFoundation
* AVSpeechSynthesizer
* XcodeGen

## Generar proyecto Xcode

Este proyecto usa XcodeGen.

```bash
xcodegen generate
```

Luego abrir el proyecto generado en Xcode y ejecutar la app.

## Limitaciones actuales

El reconocimiento de voz local sirve como apoyo educativo, pero no evalúa pronunciación de forma clínica o perfecta.

En algunos casos, el STT puede autocorregir palabras. Por eso VOZI combina:

* reconocimiento de voz;
* reglas por fonema/grupo;
* banco de palabras controlado;
* juicio adulto como apoyo.

## Roadmap

### Fase 3 — Limpieza técnica

* eliminar código que ya no pertenece al MVP;
* retirar Azure del flujo y de la documentación;
* retirar Spike STT;
* retirar sílabas, frases y misión como flujo principal;
* simplificar modelos, vistas y servicios para explicar mejor el proyecto.

### Fase 4 — UI/UX infantil

* mejorar pantalla de palabras;
* hacer tarjetas más visuales;
* mejorar botones;
* agregar feedback visual más amigable;
* mejorar experiencia para niños.

### Fase 5 — Gamificación

* conectar los 9 fonemas/grupos con 9 gatos o skins;
* agregar puntos;
* recompensas;
* colección;
* desbloqueos;
* modo desarrollador separado del modo producción.

### Fase 6 — Backend con Supabase

Supabase será una fase obligatoria del proyecto.

Objetivos:

* sincronizar perfiles;
* guardar progreso;
* preparar reportes;
* mantener privacidad;
* no subir audio crudo.

### Fase 7 — Reportes

* panel adulto mejorado;
* resumen por fonema;
* palabras logradas;
* palabras que requieren más práctica;
* exportación CSV/PDF.
