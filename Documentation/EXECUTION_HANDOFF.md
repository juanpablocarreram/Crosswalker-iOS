# Validación de ejecución — 17 de noviembre de 2026

Estado final y evidencias: [RUNTIME_COMPARISON.md](RUNTIME_COMPARISON.md) y [verification/runtime/results.json](verification/runtime/results.json).

## Acceso y referencia

- CoreSimulator y ADB funcionan en esta sesión. No se necesitan las excepciones de sandbox del handoff anterior.
- GitHub y el checkout Android coinciden en `37d3fe9e08fae3589538ec78e2f4a5cca4403df5`, rama `experiment/nuevos-assets`. Consulta en vivo guardada en `verification/runtime/github.json`.
- Se compiló e instaló Android desde ese checkout. Su código de producción quedó intacto; el test temporal se retiró del árbol Android y se conserva en `tools/android/CrossPlatformExecutionTest.kt`.

## Correcciones

- Logo con tamaño intrínseco completo, sin alturas compactas que recorten o compriman las líneas.
- Tutorial que avanza con un toque, placa del nombre en la esquina y controles elevados sobre un velo completo. Se conserva un solo estado de escritura/voz. Pausa, pestaña y ayuda autorizada funcionan durante la guía.
- Pausa crema de 48 puntos, fichas naranjas cuadradas, bordes escalonados de un punto y botón de lanzamiento verde con insignia. Se evitan emoji en los símbolos; las caras completas de los botones reciben toques.
- Diálogos posteriores con la mano de avance, altura de planificación adaptable y desplazamiento vertical/horizontal.
- Se validó el bucle ligado a la fase de escena del turno anterior: movimiento real, pausa, segundo plano y reanudación. El tablero publica progreso accesible.
- Tests actualizados a La escuela y ampliados a tutorial completo, ayuda, choque, corrección, 12 niveles, créditos y progreso tras reiniciar el proceso.

## Validación

- iPhone 18 Pro / iOS 27.0: dos pruebas UI aprobadas; campaña 12/12, créditos y persistencia.
- iPhone SE 3 / iOS 27.0: 17 pruebas de motor/sesión y un recorrido UI completo aprobados; campaña 12/12, créditos y persistencia.
- Android API 37: ocho pruebas de interfaz aprobadas, incluida campaña 12/12, tutorial y choque/reintento.
- Swift Package: 17 pruebas, cero fallos.
- iPhone Release sin firma: compilación y verificación de recursos aprobadas.
- Capturas originales, láminas comparadas, logs, resúmenes y hashes en `verification/runtime/`. Los `.xcresult` locales completos figuran en `results.json`.

Las esperas de las pruebas respetan el movimiento lento del nivel 8 y el desplazamiento automático de los créditos. No se modificaron los tiempos ni la dificultad del juego para que pasaran.

## Estado del trabajo

Los cambios siguen locales, sin commit ni push. Se conservaron las modificaciones iOS que ya existían al iniciar esta sesión. La comprobación describe los recorridos ejecutados y sus límites; no equivale a certificar todos los planes posibles ni igualdad píxel a píxel entre geometrías distintas. No se comparó acústicamente la salida entre dispositivos físicos ni se firmó/publicó una distribución.
