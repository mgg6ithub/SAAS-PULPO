---
tags: [roadmap, pulpo]
---
# Estado actual

- 2026-10-05 · Proyecto creado: bóveda y visión inicial.
- 2026-10-05 · **Prototipo v0.1** (Flutter web): Inicio con Realizadas/Actual/Futuro, Clientes (bloques y lista) con su ficha y tareas, Trabajadores, Tareas y plantillas. Crear/editar/borrar todo en paneles laterales. Trabajadores aptos por competencias y asignación automática. Datos de ejemplo guardados en el navegador. Ver [[MOC - Prototipo]].
- 2026-10-05 · Quitados los datos de ejemplo: una cuenta nueva empieza **vacía salvo las 4 plantillas** (caldera, ascensor, jardinería, limpieza). Clave de guardado `pulpo_v2` (se cambió para que los navegadores con los ejemplos arranquen vacíos).
- Tests: `flutter test` (aptos, "hecha hoy" y formularios).
- Ejecutar: `cd app` → `flutter run -d chrome`.
- 2026-10-15 · **Agenda con mapa** (iteración Jobber): Día por técnico, Semana, Mes y Tablero, con mapa lateral (OpenStreetMap). Clientes con coordenadas (`lat`/`lng`, geocodificación con Nominatim en `geo.dart`). Barra lateral oscura con ancho ajustable (arrastrar el borde o −/+). Ejecutar: servidor fijo `flutter run -d web-server --web-port 8080`.
