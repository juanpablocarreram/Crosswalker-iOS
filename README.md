# Crosswalker iOS — experiment/nuevos-assets

Port de la rama **`experiment/nuevos-assets`** del repositorio `https://github.com/Diego-Alberto-A/ADO.git`, fijado al commit **`37d3fe9e08fae3589538ec78e2f4a5cca4403df5`**. Esta versión incluye la campaña compleja: tutorial, herramientas por nivel, tráfico bidireccional, lluvia y frenado, visibilidad nocturna, rampas, vehículos sorpresa, música y créditos.

La referencia se extrae del objeto Git de esa rama, nunca de los archivos de la rama actualmente abierta en `ADO`. El 17 de noviembre de 2026 se comprobó con `git ls-remote` que GitHub mantiene ese mismo HEAD para `experiment/nuevos-assets`.

## Ejecutar

Abre `Crosswalker.xcodeproj`, selecciona **Crosswalker** y un simulador de iPhone, y pulsa **⌘R**. La app requiere iOS 16. Para instalar en un iPhone físico, configura tu equipo de firma en Xcode. Los targets de pruebas requieren iOS 17 por las bibliotecas XCTest del Xcode instalado.

## Validación

- 17 pruebas de motor, persistencia, tutorial, audio y sesión pasan en macOS.
- 339 recorridos ejecutados sobre el motor Kotlin de la rama seleccionada: 4.006 muestras comparadas con Swift, tolerancia Float de `0.000001`.
- 70 imágenes Android/iOS con dimensiones y píxeles RGBA idénticos.
- 94 recursos importados con hashes de procedencia; los dos OGG convertidos a WAV conservan exactamente el PCM decodificado.
- App para iPhone y targets de pruebas compilados sin firma.

Las pruebas de sesión se ejecutan sobre el mismo código de Session, habilitado también para macOS. La configuración AVAudioSession es específica de iOS y no forma parte de esa ejecución. CoreSimulator y el emulador Android ya están accesibles. La comparación de ejecución, capturas y resultados está en [RUNTIME_COMPARISON.md](Documentation/RUNTIME_COMPARISON.md). La reproducción acústica entre dispositivos no se ha comparado.

Consulta [el informe completo y sus evidencias](Documentation/PORT_PARITY_REPORT.md).

## Repetir las pruebas

```sh
swift test
xcodebuild -project Crosswalker.xcodeproj -scheme Crosswalker -sdk iphoneos \
  -configuration Release -derivedDataPath /tmp/crosswalker-nuevos-assets-release \
  CODE_SIGNING_ALLOWED=NO build
python3 tools/verify_bundle.py /tmp/crosswalker-nuevos-assets-release/Build/Products/Release-iphoneos/Crosswalker.app
```

La sesión actual ejecuta SwiftPM y CoreSimulator sin las excepciones de sandbox que necesitó la sesión anterior.

Para las pruebas de interfaz, selecciona un simulador con runtime disponible y ejecuta **⌘U** en Xcode.

## Regenerar desde la referencia fijada

```sh
python3 tools/android_reference.py
python3 tools/import_android_resources.py
python3 tools/generate_android_reference.py
swift -module-cache-path /tmp/crosswalker-clang-cache tools/verify_android_pixels.swift "$PWD"
python3 tools/generate_xcode_project.py
```

`android_reference.py` extrae el commit fijado desde el repositorio hermano `../ADO` a `.reference-source/`, ignorado por Git, y valida sus archivos contra los objetos Git. El importador usa `sips` y FFmpeg; si no hay FFmpeg en PATH, usa el incluido en Android Studio. El generador de referencias usa el compilador Kotlin y JBR de Android Studio. No descarga dependencias.

La campaña está en `Crosswalker/Resources/campaign.json`; fuentes, música, SFX y licencias también están incluidos. Los sprites están en `Crosswalker/Assets.xcassets`. Las estrellas, preferencias y finalización del tutorial se guardan localmente mediante UserDefaults.
