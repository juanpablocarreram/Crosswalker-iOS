# Comparación de ejecución de iOS y Android

17 de noviembre de 2026. Continuación de `EXECUTION_HANDOFF.md`.

## Referencia y acceso

GitHub confirma `experiment/nuevos-assets` en **37d3fe9e08fae3589538ec78e2f4a5cca4403df5**. El checkout Android utilizado también tiene ese HEAD y no se modificó su código de producción. La única fuente añadida temporalmente fue la instrumentación de comparación, conservada en [tools/android/CrossPlatformExecutionTest.kt](../tools/android/CrossPlatformExecutionTest.kt). La consulta remota y su fecha están en [github.json](verification/runtime/github.json).

Se comprobó el acceso efectivo a CoreSimulator, ADB y los repositorios. Se construyeron, instalaron y ejecutaron las apps. Esta comprobación incluye interacción sobre pantallas reales de los simuladores; no se deduce su resultado de la compilación o de las pruebas puras del motor.

## Dispositivos y resultados

| Entorno | Recorrido | Resultado |
| --- | --- | --- |
| iPhone 18 Pro, iOS 27.0, 402 × 874 puntos | Tutorial, ayuda, pausa, segundo plano, choque, mejora del plan, campaña completa, créditos y persistencia tras reiniciar el proceso | 2 pruebas UI aprobadas; campaña 12/12, créditos y persistencia |
| iPhone SE de tercera generación, iOS 27.0, 375 × 667 puntos | Mismo recorrido completo en pantalla compacta; pruebas de motor/sesión dentro del simulador | 18 pruebas aprobadas: 17 de motor/sesión y un recorrido UI completo |
| Medium Phone, API 37, 720 × 1600 px, densidad 280 | Tutorial y campaña con los controles de Compose; choque/reintento; siete pruebas originales del tutorial | 8 pruebas de instrumentación aprobadas, incluida campaña 12/12 |
| Swift Package en macOS | Motor, repositorio, tutorial, audio y sesión, incluido avance/cancelación/reanudación del bucle | 17 pruebas, 0 fallos |
| App iPhone Release y recursos del paquete | Compilación sin firma e integridad de imágenes, fuentes, campaña, audio y tonos | BUILD SUCCEEDED; 70 imágenes, 24 recursos, cinco fuentes y siete tonos verificados |

La resolución del emulador Android se redujo conservando aproximadamente 411 dp de ancho para aliviar su renderizado por software. El primer arranque frío mostró un ANR de System UI; se resolvió antes de la ejecución usada como evidencia. No se alteraron las reglas ni los tiempos del juego.

## Qué se comprobó mediante interacción

- Abrir el mapa, cambiar mundos y comprobar el bloqueo inicial del nivel 5.
- Recorrer todas las líneas y objetivos del tutorial. Un toque avanza una línea, incluso mientras se está escribiendo. El paso del mapa baja el panel y exige volver a abrirlo.
- Cerrar/reabrir el panel y pausar sin perder el paso. Mantener bloqueadas las pestañas ajenas al objetivo; tocar el diálogo no sustituye la elección real del cruce.
- Abrir y cerrar la explicación de Mirar durante el paso que lo permite, escoger cruce y habilidad, y lanzar desde el botón real.
- Esperar cambios de posición observables y obtener victorias con el bucle normal de la app. Las pruebas no llaman a `tick()` ni inyectan una simulación o un plan preparado.
- Pausar/reanudar la simulación. En iOS también salir a SpringBoard y regresar. En Android se comprueba que el tiempo de simulación permanece fijo durante la pausa.
- Retirar Mirar, elegir el cruce derecho, provocar una colisión, volver al plan, corregirlo y ganar. El reintento conserva un plan editable.
- Preparar y ganar los 12 niveles con sus peatones, cruces y herramientas: celular, audífonos, acompañamiento, rampas, doble sentido, lluvia, frenado y noche. Las soluciones proceden de los planes Android fijados; no se rebajaron las dificultades.
- Llegar a créditos al ganar el nivel 12. En iOS volver al inicio, terminar el proceso, abrirlo de nuevo y comprobar 12/12 y el último nivel disponible.

En el nivel 8 hay una espera real prolongada antes de que caminen: el test anterior imponía ocho segundos y terminaba demasiado pronto. Se amplió la espera del test, conservando la física y los tiempos de la app.

## Correcciones iOS verificadas

1. **Título principal:** el texto Jersey10 utiliza sus dimensiones intrínsecas, sin encajarlo en alturas menores que sus métricas. La comparación con Android llevó a retirar también las alturas compactas restantes entre las dos líneas del logo.
2. **Tutorial y diálogo:** avance directo con un toque; nombre en una placa sobre la esquina, color del personaje y caja con el relleno de Android. El texto conserva su animación de escritura y sus resaltados; fuera del tutorial se mantiene la mano para revelar o avanzar el texto.
3. **Capas del tutorial:** velo completo y controles elevados por encima. El diálogo conserva un único propietario de su estado de escritura/voz. Ya no se abren agujeros que aclaren el fondo rectangular alrededor del retrato. Diálogo, pausa y pestaña permanecen visibles; cada cruce se resalta por separado; la mano señala el objetivo correspondiente.
4. **HUD:** pausa de 48 puntos con cara crema; fichas cuadradas naranjas y leyenda FICHAS. Se conserva una descripción accesible con las fichas restantes.
5. **Paneles y botones:** bordes de un punto y esquinas escalonadas, transparencia del panel completo, tipografía Jersey10 en acciones y botón de lanzamiento verde con su insignia de reproducción. Los símbolos se fuerzan a presentación de texto para evitar emoji. Las caras completas de los botones forman su superficie táctil.
6. **Planificación:** altura según el espacio disponible y contenido desplazable, conservando el tablero estable. Se verifica también en el iPhone SE.
7. **Simulación:** se conserva y valida el bucle ligado a la fase de escena del handoff. La descripción accesible del tablero publica el progreso real de cada peatón. Hay evidencia de avance, pausa, reanudación y resultado; no se atribuye la avería original a una única causa sin esa reserva.
8. **Pruebas:** título de mundo corregido a La escuela, identificadores estables para no confundir el diálogo que menciona una acción con el botón de esa acción, recorrido completo y preferencias de prueba aisladas con una opción para reiniciar el proceso sin borrarlas.

## Capturas comparadas

Las imágenes son capturas reales, sin reconstruir la interfaz. Las láminas solo las escalan y colocan juntas. Las barras del sistema, las áreas seguras y la relación de aspecto pertenecen a cada dispositivo. Las transiciones finitas se dejan terminar antes de capturar. Las animaciones continuas y el texto en curso se capturaron en instantes distintos: no son imágenes sincronizadas píxel a píxel. El inicio Android también se capturó fuera de la instrumentación, con su animación normal.

| Estado | Comparación |
| --- | --- |
| Menú y título completos | [Inicio](verification/runtime/comparisons/home.png) |
| Diálogo elevado y panel | [Tutorial](verification/runtime/comparisons/tutorial-00.png) |
| Mapa y pestaña que permite continuar | [Paso del mapa](verification/runtime/comparisons/tutorial-map.png) |
| Selección del cruce | [Cruces](verification/runtime/comparisons/tutorial-crossing.png) |
| Ayuda durante el tutorial | [Explicación de Mirar](verification/runtime/comparisons/tutorial-tool-help.png) |
| Lanzamiento habilitado | [Lanzar](verification/runtime/comparisons/tutorial-launch.png) |
| Movimiento real | [Simulación](verification/runtime/comparisons/level-01-running-moved.png) |
| Choque y reintento | [Resultado del choque](verification/runtime/comparisons/collision-result.png) |
| Planificación con lluvia | [Nivel 7](verification/runtime/comparisons/level-07-plan.png) |
| Noche y faros | [Nivel 9](verification/runtime/comparisons/level-09-running.png) |
| Tres peatones y mejoras compartidas | [Plan del nivel 12](verification/runtime/comparisons/level-12-plan.png) |
| Créditos finales | [Campaña completada](verification/runtime/comparisons/level-12-won.png) |

Capturas originales: [iPhone](verification/runtime/ios/), [iPhone SE](verification/runtime/compact/) y [Android](verification/runtime/android/). Los logs y resúmenes de pruebas se conservan en el mismo directorio. Los `.xcresult` completos, incluidas grabaciones de XCTest, quedan en las rutas locales indicadas en `results.json`.

## Repetir

```sh
swift test
xcodebuild -project Crosswalker.xcodeproj -scheme Crosswalker \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -parallel-testing-enabled NO -resultBundlePath /tmp/crosswalker-check.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Para Android, copiar `tools/android/CrossPlatformExecutionTest.kt` al source set `androidTest` de `../ADO`, construir `assembleDebug assembleDebugAndroidTest`, instalar ambos APK y ejecutar:

```sh
adb shell am instrument -w -r \
  -e class com.example.crosswalker.CrossPlatformExecutionTest,com.example.crosswalker.TutorialTest \
  com.example.crosswalker.test/androidx.test.runner.AndroidJUnitRunner
adb pull /sdcard/Android/data/com.example.crosswalker/files/execution/ /tmp/android-captures/
```

La instrumentación genera capturas y usa las acciones reales de la interfaz. Para reconstruir las láminas con las capturas exportadas:

```sh
python3 tools/export_runtime_captures.py /tmp/crosswalker-check.xcresult ios
swift tools/make_runtime_comparisons.swift "$PWD"
```

## Alcance

Se contrastaron los recorridos descritos y sus capturas. Esto no prueba todas las combinaciones posibles ni una igualdad visual de cada píxel entre sistemas con geometrías diferentes. No se comparó acústicamente la salida de audio entre dispositivos físicos, ni se firmó o publicó una versión para distribución.
