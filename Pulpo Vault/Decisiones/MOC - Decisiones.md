---
tags: [moc, decisiones]
---
# MOC - Decisiones

## Qué es y para qué sirve
Registro de decisiones, una línea cada una: fecha · decisión · por qué. Sirve para no repetir debates ya cerrados.

## Log
- 2026-10-05 · Nombre provisional "Pulpo" · todavía no hay nombre; el logo será un pulpo morado.
- 2026-10-05 · ~~Prototipo en HTML/CSS/JS~~ → **prototipo en Flutter (web) desde el principio** · así no se rehace nada: el mismo código vale después para Android e iOS; para un panel con login no importa la carga inicial.
- 2026-10-05 · Datos en local al principio, Supabase después · para enseñar el prototipo sin depender de un servidor.
- 2026-10-05 · Hosting del prototipo: Cloudflare Pages (o GitHub Pages) · Flutter web genera una web estática.
- 2026-10-05 · Backend en Supabase/PostgreSQL (probable) · por decidir del todo.
- 2026-10-05 · ~~Primer caso: comunidad de vecinos~~ → **SaaS de automatización de mantenimiento para empresas pequeñas de mantenimiento** (ascensores, contra incendios…); sus clientes pueden ser edificios, colegios, hospitales… · más sencillo y viable de vender desde el principio.
- 2026-10-05 · Una tarea creada dentro de un cliente va fija a ese cliente (sin selector) · para que no haya malentendidos. Solo se elige cliente al crear desde la vista Tareas.
- 2026-10-05 · Formularios en **ventana centrada** que sube desde abajo (hoja de iOS), arrastrable y **acoplable a la derecha** con un botón; se recuerda el modo elegido · el panel lateral fijo abrumaba.
- 2026-10-05 · Formularios con lo esencial a la vista y el resto en "Más detalles" plegable · demasiados campos de golpe abrumaban al usuario.
- 2026-10-05 · Inicio = **calendario**: vista principal "Días" (horizontal, por días) + "Calendario" (mes por bloques); el tablero tipo Trello queda como vista secundaria · el objetivo es automatizar, no gestionar tarjetas a mano; el tablero sirve para ver de un vistazo y lanzar el pulpo.
- 2026-10-05 · Sin doble clic en la cabecera de la ventana · retrasa ~300 ms los botones de la cabecera.

## Notas
— el log de arriba

## Archivos clave
— aún no hay código
