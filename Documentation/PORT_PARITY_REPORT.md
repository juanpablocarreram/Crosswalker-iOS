# Port de experiment/nuevos-assets: auditoría, correcciones y validación

Fecha: 17 de noviembre de 2026. Este informe sustituye el de la campaña de `main`.

Actualización de ejecución: [comparación real de iOS y Android, capturas y correcciones de interfaz](RUNTIME_COMPARISON.md). Las limitaciones de acceso de la primera sesión que aparecen en los registros históricos quedaron resueltas.

## 1. Fuente de verdad y procedencia

- Repositorio: `https://github.com/Diego-Alberto-A/ADO.git`.
- Rama solicitada: **`experiment/nuevos-assets`**.
- Commit fijado: **`37d3fe9e08fae3589538ec78e2f4a5cca4403df5`**, 15 de noviembre de 2026, «chore: organiza los recursos y limpia el repositorio».
- La referencia local y la consulta en vivo `git ls-remote origin refs/heads/experiment/nuevos-assets`, ejecutada el 17 de noviembre, apuntan a ese mismo commit.
- Se extrajo el objeto Git exacto en `.reference-source/`, ignorado por Git. Los scripts validan los archivos extraídos contra los hashes de objetos del commit. No leen la campaña ni el motor desde el checkout actual de `ADO`.
- `android-source-lock.json` registra rama, commit, SHA-256 del motor y procedencia/hash de cada recurso importado. El motor tiene SHA-256 `90a1352cf056e16cc2ed1dcdb057df113b599181583b89a5f34282995827fa99`.

La base iOS previa a la primera intervención ya estaba orientada a este commit. Se recuperó esa base desde su Git y se revirtieron las sustituciones de campaña, motor, UI y audio hechas para la versión simple. Después se auditaron y corrigieron defectos de la base recuperada. No se presenta esa recuperación como si todos sus sistemas se hubieran escrito de nuevo.

## 2. Entorno Android de esta rama

| Elemento | Valor declarado |
| --- | --- |
| Android SDK | compile 37, target 37, mínimo 24 |
| AGP | **9.3.3**, distinto del 9.4.1 de la otra versión |
| Gradle | 9.6.0 |
| Plugin Kotlin Compose | 2.2.10 |
| Compatibilidad Java / daemon | Java 11 / JDK 25 |
| Compose BOM | 2026.02.01 |
| Activity Compose / Core KTX | 1.13.0 / 1.19.0 |
| Lifecycle runtime KTX | 2.11.0 |
| Pruebas | JUnit 4.13.2; org.json 20231013; AndroidX JUnit 1.3.0; Espresso 3.7.0 |

Arquitectura Android: Activity con Jetpack Compose, Session ViewModel, estados observables, repositorio JSON y SharedPreferences. Los modelos usan List, MutableMap y MutableSet; física y relojes son Float. La simulación se invoca mediante corrutina cada 50 ms; el motor no tutorial subdivide cada invocación en pasos de como máximo .02 s. Las corrutinas de diálogo, lluvia, impactos y transiciones son independientes del avance de la simulación.

**Ubicación real de recursos:** `app/build.gradle.kts` sustituye los sourceSets por `assets/game/res` y `assets/game/files`. Esa es la fuente importada; no `app/src/main/res` de la otra rama.

Además de ejecutar el motor Kotlin y las reglas de tutorial para las referencias puras, se compiló e instaló el APK Debug de este commit y su instrumentación. La ejecución completa está documentada en RUNTIME_COMPARISON.md.

## 3. Sistemas recuperados y auditados

| Android | iOS | Comportamiento conservado |
| --- | --- | --- |
| `game/Simulation.kt` | `Core/Simulation.swift` | Campaña tutorial y física compleja, tráfico, colisiones, mensajes y puntuación |
| `data/GameRepository.kt` | `Core/GameRepository.swift` | Campaña, mejores estrellas, desbloqueos, tutorial y reset de progreso |
| Session de `MainActivity.kt` | `Session.swift` | Cruces iniciales de campaña, intercambio de peatones, presupuesto, selección y pausa |
| `MainActivity.kt`, `Dialogue.kt`, `TutorialStep.kt`, `TutorialOverlay.kt` | `UI/Screens.swift`, `Core/PresentationRules.swift` | HUD, panel de planificación, herramientas por nivel, explicaciones, diálogo y tutorial |
| `Board.kt`, `BoardScenery.kt` | `UI/Board.swift` | Escena 360 × 460, tiles, escenarios por mundo, sprites animados, lluvia, niebla, luces e impactos |
| `PixelUi.kt`, `CraftArt.kt`, tema | `UI/CraftArt.swift`, `UI/Dialogs.swift` | Paleta pixel art, tipografías, paneles, fichas, retratos y modales |
| `HomeMenu.kt`, `CampaignCredits.kt` | `UI/HomeAndCredits.swift` | Calle animada de inicio, cambios de escenario, créditos, enlaces y Fundación ADO |
| `Transitions.kt` | `UI/Transitions.swift` | Iris inicial, transiciones hacia delante/atrás y fundido de créditos |
| `audio/AudioMapping.kt`, `SoundEngine.kt` | `Session.swift`, `Core/PresentationRules.swift`, AVFoundation | Música por pantalla/mundo, ambiente de lluvia, voz de diálogo, efectos y resultados |

La campaña vuelve a ser la de esta rama: 12 niveles, tres mundos, Ana, Tomás, Leo, Luz y Mateo según los niveles; nueve herramientas con disponibilidad específica. Se mantienen celular, audífonos, acompañamiento, rampas, zona de velocidad, iluminación, faros y reflectores. No se conserva el botón de emergencia de la campaña simple.

El tráfico complejo conserva vehículos de carril, vehículos contrarios que no ceden el paso, vehículos sorpresa de un solo uso y reutilización de un vehículo en niveles de un peatón. Las colisiones barridas identifican el peatón, carril, posición, velocidad y papel del vehículo que causó el impacto. Los resultados muestran primero el impacto y esperan 900 ms; ganar el nivel 12 lleva a créditos y volver al inicio muestra el cierre de campaña.

## 4. Correcciones realizadas sobre la base iOS recuperada

1. **Compilación del tablero:** se renombró el contador de simulación que se llamaba `frame`, porque chocaba con la propiedad `UIView.frame` de tipo CGRect.
2. **Cruces iniciales:** se declaró explícitamente `[Int]` para evitar que la comparación con `blockedCrossing: Int?` hiciera inferir una colección de opcionales y rompiera la compilación.
3. **Tutorial:** Pausa y la pestaña del plan permanecen operativas durante la guía; la ayuda de herramienta está permitida cuando el paso activo pide Mirar. Antes el port solo permitía el objetivo exclusivo y bloqueaba estos controles.
4. **Reglas verificables:** se trasladaron las reglas de tutorial y selección musical a `Core/PresentationRules.swift`, compartido por la app y las pruebas. Los pasos se comparan con resultados ejecutados desde `TutorialStep.kt` de la rama fijada.
5. **Diálogo:** intervalo corregido de 15 a **25 ms** por unidad UTF-16. El texto completo reserva el espacio de la caja mientras se revela; se añadieron resaltados de personas, objetos/controles y lugares, con límites de palabras, normalización de acentos y prioridades del léxico Android.
6. **Voces:** seis blips DTMF por personaje, elegidos con el hash UTF-16 de Kotlin, cada tercer carácter y duración solicitada de 18 ms; se mantiene el bucle de voz de fondo independiente.
7. **Transiciones:** se añadió el iris inicial de **820 ms** que faltaba; se conservan los 700 ms de cambios de pantalla y la excepción de apertura al volver al inicio. El borde del iris usa Cream de la rama correcta.
8. **Modales:** etiqueta inclinada sobre la esquina; entrada .9 → 1.05 → 1 en 200 ms y salida a .94 en 140 ms, respetando la acción diferida al cerrar. Color del texto calculado con el umbral de luminancia .36 del Android.
9. **JSON numérico:** campos de carril, offset contrario y trafficPace pasan por Double y después Float, como `getDouble/optDouble().toFloat()` del original.
10. **Pruebas de sesión ejecutables:** Session usa Combine y comparte su código real con Swift Package. Solo la configuración AVAudioSession está condicionada a iOS. Esto permite ejecutar su lógica en macOS sin sustituirla por un mock.
11. **Proyecto Xcode:** regenerado con fuentes y recursos actuales; app con mínimo iOS 16 y targets XCTest con mínimo iOS 17, evitando los avisos de enlazado del XCTest instalado.
12. **Herramientas y trazabilidad:** importación, referencias y verificación fijadas a la rama elegida. Se retiraron el tono y las evidencias de la campaña simple para evitar resultados mezclados.

## 5. Constantes y fórmulas contrastadas

| Sistema | Regla de esta rama |
| --- | --- |
| Paso externo / interno | .05 s / como máximo .02 s |
| Cruces / salida / meta | [.25, .5, .75] / y=.91 / y≤.08 |
| Tráfico complejo | loopLength=1.4×trafficPace; loopStart=(1-loopLength)/2; doble resto Float |
| Velocidad base | abs(lane.speed)×trafficPace; ×.55 con speed_zone fuera del tutorial |
| Tráfico contrario | velocidad base ×1.08; no cede el paso |
| Aceleración / reacción | .08 / .35 s |
| Frenado seco / lluvia | .12 / .055 |
| Distancia de parada | v×.65 + v²/(2×deceleración) |
| Paso con lluvia / celular | velocidad peatonal ×.85 / ×.65 en la simulación compleja |
| Predicción de hueco | 41 muestras, márgenes .07/.12; conserva la división por trafficPace del horizonte |
| Colisión barrida | intervalos solapados; radios .115 horizontal y .065 vertical; no barre saltos de wrap≥.7 |
| Visibilidad | factores de luz, faros, reflector, acompañamiento, niebla y audífonos del motor original |
| Vehículo sorpresa | borde -.2 o 1.2; tiempo al centro mínimo .25; velocidad calculada para ese encuentro; expiración +.4 |
| Límite de tiempo | ≥90 s en motor complejo; >90 en tutorial |
| Estrellas | 0 si no gana; 3 si coste≤parCost no tutorial o presupuesto×.65; 2 en otro caso |
| Presentación | diálogo 25 ms; resultados 900 ms; iris inicial 820 ms; pantallas 700 ms |
| Créditos | espera 1.5 s, avance 42 unidades/s; escenarios cada 12 s |

El tutorial conserva su ruta de simulación distinta de la física compleja. No se añadieron inmunidades por reflector ni se sustituyó la colisión barrida por la comprobación simple de la otra versión. Las particularidades de la lógica de origen se mantienen en vez de ajustar valores para facilitar niveles.

## 6. Integración y verificación de recursos

- **94 recursos de la rama:** 70 imágenes, cinco fuentes, seis archivos de licencia/crédito, campaña JSON y 12 archivos de audio.
- Las 70 imágenes conservan dimensiones y píxeles RGBA exactamente iguales al decodificar Android e iOS. Incluyen personajes y fotogramas, vehículos, terreno, decoración, obstáculos, iconos, manos y logo Fundación ADO.
- Archivos que ya son compatibles se copian byte a byte. Los dos OGG (`music_menu`, `rain`) se convierten a WAV PCM de 16 bits conservando canales y frecuencia; se comparó el PCM decodificado del OGG contra el del WAV y resultó idéntico.
- Los tonos de ACK y DTMF se generan para sustituir ToneGenerator. Se mantienen frecuencias, selección y duraciones del original. No son una grabación bit a bit de la salida del sintetizador Android ni una prueba de igualdad acústica en dispositivos.
- Verificación del `.app` Release: 70 nombres presentes en Assets.car; hashes de los 24 recursos importados no gráficos correctos; cinco fuentes registradas en Info.plist; siete tonos generados y manifiesto de privacidad presentes.
- Se mantienen las licencias adicionales de la base iOS. El icono de aplicación iOS existente se conserva; la equivalencia visual entre el icono iOS y las máscaras de launcher adaptativo Android requiere comprobación visual.

Evidencias: `android-source-lock.json`, `android-pixel-verification.json`, `android-reference.json` y `bundle-verification.json`.

## 7. Pruebas ejecutadas y compilación

Entorno: Xcode 27.2 (27B52), Swift 6.4.2, macOS arm64.

| Comprobación | Resultado |
| --- | --- |
| Pruebas Swift Debug | **17 ejecutadas, 0 fallos** |
| Pruebas Swift optimizado Release | **16 ejecutadas, 0 fallos**, mediante xctest sobre el bundle optimizado |
| Recorridos Kotlin vs Swift | **339**, con **4.006 muestras**; 131 victorias y 208 reintentos |
| Tolerancia numérica | .000001 absoluta para Float; estados, mensajes, identidades, costes y estrellas exactos |
| Campos contrastados | tiempo, posiciones, done, velocidades, frenado, coches contrarios y sorpresa, visibilidad, feedback, velocidad de impacto, razón y estrellas |
| Tutorial | matriz de pasos ejecutada desde el Kotlin de esta rama; objetivos y acciones coincidentes |
| Sesión | presupuesto, intercambio, selección inicial, desbloqueo, pausa, transiciones, reset, permisos tutorial, créditos finales y cancelación de resultados |
| Audio puro | música por pantalla/mundo y hash de voz por personaje |
| Recursos | 70/70 imágenes RGBA idénticas; PCM de ambos OGG igual; pertenencia al paquete comprobada |
| App iPhone Release | **BUILD SUCCEEDED**, sin firma |
| App y tests iPhone Debug | **TEST BUILD SUCCEEDED**, sin firma |
| Scripts | extracción de referencia desde cero y validación contra objetos Git probadas; Python compilado sin errores |
| `git diff --check` | sin errores |

La matriz conserva los 27 planes de referencia previos y añade 26 variantes por cada uno de los 12 niveles: sin preparación, habilidades necesarias, combinaciones de mejoras, ordenaciones de cruces, retirada de habilidades críticas, cruces inválidos/bloqueados, duplicados y herramientas no disponibles. Algunos planes se prueban directamente contra el motor aunque excedan el presupuesto: esto permite contrastar su comportamiento; la UI aplica el presupuesto por separado.

Las pruebas de sesión se ejecutan en macOS sobre el código real. La ejecución posterior de XCTest en CoreSimulator y de instrumentación sobre Android complementa esa evidencia con interacción real; véase RUNTIME_COMPARISON.md.

SwiftPM Release enlazó el bundle pero su paso de generación dSYM falló con `Operation not permitted`. Se ejecutó el bundle optimizado directamente con xctest y pasaron sus 16 pruebas. No se presenta la invocación completa de SwiftPM Release como exitosa. La compilación Release de la app con Xcode sí pasó.

Los avisos de metadatos AppIntents indican ausencia de dependencia AppIntents. En la primera sesión CoreSimulator rechazaba la conexión y el compilador necesitó una excepción temporal para su sandbox de macros. La sesión de ejecución posterior ya permite compilar y ejecutar en simuladores sin esas opciones.

Los logs de ejecución y resúmenes de compilación están en `verification/`.

## 8. Reproducibilidad

Desde la raíz iOS:

```sh
python3 tools/android_reference.py
python3 tools/import_android_resources.py
python3 tools/generate_android_reference.py
swift -module-cache-path /tmp/crosswalker-clang-cache tools/verify_android_pixels.swift "$PWD"
python3 tools/generate_xcode_project.py

CLANG_MODULE_CACHE_PATH=/tmp/crosswalker-clang-cache swift test --disable-sandbox \
  --cache-path /tmp/crosswalker-spm-cache --scratch-path /tmp/crosswalker-new-swift-build

xcodebuild -project Crosswalker.xcodeproj -scheme Crosswalker -sdk iphoneos \
  -configuration Release -derivedDataPath /tmp/crosswalker-nuevos-assets-release \
  CODE_SIGNING_ALLOWED=NO 'OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sandbox' build

python3 tools/verify_bundle.py /tmp/crosswalker-nuevos-assets-release/Build/Products/Release-iphoneos/Crosswalker.app
```

Los scripts requieren macOS y el compilador Kotlin/JBR de Android Studio. Si no hay FFmpeg en PATH, el importador extrae la distribución que incluye Android Studio en un directorio de construcción ignorado. No se descarga software. Los hashes de referencia impiden volver a importar por accidente la campaña simple de otro checkout.

## 9. Límites de aceptación

Se corrigió el destino de versión y hay evidencia de paridad del motor en los planes ejecutados, de lógica de sesión y de integridad de recursos. No es una prueba exhaustiva de todas las combinaciones posibles.

La navegación, el tutorial, la simulación y las capturas se verifican en RUNTIME_COMPARISON.md. Siguen fuera de esta comprobación la equivalencia acústica en dispositivos físicos y las máscaras del icono de launcher. GitHub se comprobó en vivo y mantiene el commit fijado.

No se ha firmado, instalado ni enviado la app a TestFlight. No se afirma «perfección 100 %» ni «listo para producción» a partir de compilaciones y pruebas lógicas; la comparación visual realizada y sus límites figuran en el informe de ejecución; la comparación acústica sigue pendiente.
