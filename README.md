# Crosswalker para iOS 1.0

Juego de seguridad vial en español, con 12 niveles en tres mundos. Esta versión nativa usa SwiftUI, Core Graphics y AVFoundation. Toma como referencia la versión final de Android de la rama `experiment/nuevos-assets`, commit `37d3fe9`.

El proyecto incluye la campaña, imágenes, tipografías, audio y licencias. Xcode compila los recursos locales. La aplicación funciona sin conexión y guarda estrellas, ajustes y progreso en el dispositivo.

## Obtener el proyecto

Si ya clonaste el repositorio, trabaja desde esa carpeta. Si todavía no lo tienes en la Mac:

```sh
git clone https://github.com/juanpablocarreram/Crosswalker-iOS.git
cd Crosswalker-iOS
open Crosswalker.xcodeproj
```

Si recibiste `Crosswalker-iOS.zip`, descomprímelo y abre `Crosswalker.xcodeproj` desde la carpeta extraída. Los recursos están incluidos y no se requiere el proyecto de Android.

## Ejecutar en una Mac

1. Instala **Xcode** desde la Mac App Store y ábrelo una vez. Acepta la licencia e instala los componentes que te pida.
2. Abre **Crosswalker.xcodeproj** con doble clic. El esquema compartido **Crosswalker** debe aparecer en la barra superior de Xcode.
3. Selecciona un **simulador de iPhone** en el selector de destino. Si no hay ninguno, descarga un runtime de iOS desde **Xcode → Settings → Components/Platforms**, según tu versión de Xcode. Puedes crear un dispositivo desde **Window → Devices and Simulators → Simulators**.
4. Presiona **⌘R** o el botón triangular **Run**. Xcode compila, inicia Simulator y abre el juego. Para esta prueba no necesitas configurar un equipo de firma.
5. En el menú toca **JUGAR → Mi primer cruce → PREPARAR EL PLAN**. Abre el plan y sigue el tutorial. En una partida nueva solo estará abierto el nivel 1. Cada victoria abre el siguiente, incluso si está en otro mundo.
6. Para repetir la prueba desde cero, usa **REINICIAR PROGRESO** en el menú de inicio. Esta acción borra únicamente el progreso de la instalación en la que la realizas.

El proyecto tiene iOS 16 como mínimo de despliegue. Usa el runtime de simulador disponible en tu versión de Xcode.

### Probar en un iPhone físico

1. Conecta el iPhone por USB y acepta **Confiar** si el dispositivo lo solicita.
2. En **Xcode → Settings → Accounts**, inicia sesión con tu cuenta de Apple. En el navegador de Xcode, elige el proyecto **Crosswalker**, el target **Crosswalker** y la pestaña **Signing & Capabilities**.
3. Activa **Automatically manage signing** y selecciona tu **Team**. Si Xcode avisa que `com.example.crosswalker` no está disponible para tu equipo, asigna un identificador propio, por ejemplo `mx.tunombre.crosswalker`.
4. Selecciona tu iPhone como destino. Activa **Developer Mode** en el dispositivo si Xcode lo solicita y pulsa **⌘R**.

La distribución de un IPA o mediante TestFlight requiere un archivo firmado y se hace aparte desde Xcode.

## Qué comprobar al jugar

- El mapa desliza solo las tarjetas. Los niveles cerrados conservan su título, número y candado.
- Las asignaciones iniciales, las habilidades y las mejoras de calle coinciden con los datos de campaña de Android.
- Cambiar de peatón abre **Habilidades**. Al exceder el presupuesto aparece el aviso con las fichas disponibles.
- En lluvia y de noche se muestran los efectos del tablero. **Bajar velocidad** resalta los coches con un aura y un reloj.
- La victoria del nivel 12 lleva a los créditos con la canción de cierre y el logo de Fundación ADO. Al volver al menú aparece **Seguir jugando**.

## Validación

Las cinco pruebas de Swift Package pasaron antes de preparar esta versión. Incluyen 27 recorridos de referencia de Android con victorias y fallos en los 12 niveles, tráfico en ambos sentidos, lluvia y cruces nocturnos. La compilación completa y la revisión visual y sonora en iOS se verifican en una Mac con Xcode.

- **Motor y persistencia:** ejecuta `swift test` en la raíz del repositorio.
- **Aplicación y navegación:** elige un simulador en Xcode y ejecuta **Product → Test** (**⌘U**) en el esquema **Crosswalker**.
- **Revisión manual:** usa la lista de la sección anterior. Revisa también que el sonido respete el ajuste de **Sonidos** y que el progreso se conserve al cerrar y volver a abrir la app.

## Recursos

- Los sprites están en `Crosswalker/Assets.xcassets/`. Los archivos PNG mantienen los píxeles de sus recursos WebP de Android.
- La campaña, tipografías, audio y licencias están en `Crosswalker/Resources/`. Las dos pistas Ogg se incluyen como WAV para reproducirlas con AVFoundation.
- Si añades un archivo Swift o un recurso, agrégalo al target en Xcode o ejecuta `python3 tools/generate_xcode_project.py` para volver a generar el proyecto.
