---
tags: [roadmap, pulpo, plan]
---
# Plan del prototipo

> El prototipo sirve para **decidir hacia dónde va Pulpo**, no es el producto final. Cada fase termina con algo que se puede probar en la app.
> Plan acordado el 2026-10-15. Sustituye al plan por fases anterior (el del chat).

## Fase 1 · Identidad visual (pulir lo que hay) ✅ 2026-10-15
Que la interfaz tenga ya sus **rasgos característicos**, aunque no esté terminada al 100 %.
- [x] Fondo y superficies con un tinte propio (blanco lavanda), radios y sombras unificados.
- [x] Tipografía propia en títulos, cifras y cabeceras de tarjeta (Plus Jakarta Sans).
- [x] Componentes coherentes en todas las pantallas: cabeceras, pastillas de estado, avatares (persona redonda, cliente cuadrado), estados vacíos.
- [x] Regla de "cuantos menos iconos, mejor" aplicada en todas partes.

## Fase 2 · Funcionalidad básica completa ✅ 2026-10-15
> Agenda: filtros (técnicos por avatar, tipo, estado), ficha rápida al pulsar una tarea, crear desde un hueco (Día/Semana), panel "Sin asignar", "Nueva tarea" en la cabecera. Mapa: colorear por cliente/técnico/tipo, leyenda y encuadrar. Pulsar el nombre de un técnico en la vista Día = ver solo a ese técnico.
Entrar en Agenda, Clientes y Trabajadores y **poder hacerlo todo desde cero**.
- [x] Crear cliente, trabajador y tarea con todos sus datos, desde cualquier sitio.
- [x] **Agenda interactiva:**
  - [x] Filtros: técnico, tipo, estado (vencidas, sin asignar…).
  - [x] Pulsar una tarea → **ficha rápida**: cambiar cliente, técnico, fecha y hora, marcar como hecha, editar, borrar.
  - [x] **Crear desde un hueco** de la agenda (Día/Semana) con fecha, hora y técnico ya rellenos.
  - [x] Panel de **sin asignar** para coger trabajos y asignarlos rápido.
  - [x] Botón "Nueva tarea" en la propia Agenda.
- [x] **Herramientas del mapa:** filtros de lo que se ve (vencidas, sin asignar, por técnico) y colorear por técnico o por cliente, con leyenda.

## Fase 3 · Al barro: mapa, rutas y planificación (el pulpo planifica)
Basado en [[Rutas y planificador (iteración OptimoRoute)]].
- [ ] **Puntero o lazo** en el mapa para seleccionar tareas y crear rutas a mano.
- [ ] Criticidad (4 niveles) y ventana horaria en las tareas; horario y punto de salida por técnico.
- [ ] **Algoritmo de planificación** del día o la semana: técnico apto + criticidad + ventana + horario + distancia.
- [ ] Rutas dibujadas por técnico, con paradas numeradas, km y tiempo.
- [ ] Lista de "Sin programar" con su motivo, deshacer y tareas fijadas.

## Fase 4 · Trabajadores: vista propia y grupos
- [ ] **Vista por trabajador:** el trabajador a la derecha y, a la izquierda, sus bloques del día o la semana en una **línea de tiempo vertical**. Cada bloque lleva su punto y su duración, y una línea une al trabajador con el bloque que está haciendo ahora.
- [ ] **Grupos de trabajo:** equipos que solo contienen trabajadores (crear, renombrar, añadir y quitar). Se pueden usar como filtro en Agenda y Mapa.

## Fase 5 · El día del técnico
- [ ] Vista móvil con la ruta de hoy y acceso a la navegación.
- [ ] Ficha de visita: checklist, notas, fotos, firma y "Hecha", que programa la siguiente.
- [ ] Avisos e imprevistos (avería urgente → replanificar).

## Fase 6 · Entrada de datos realista
- [ ] Importar desde Excel o CSV (clientes, ubicaciones, equipos) con vista previa y errores.
- [ ] Primeros pasos guiados con plantillas por sector.
- [ ] Edición en lote.

## Fuera del prototipo
Facturación, usuarios y permisos reales, pagos y backend (Supabase). Los datos siguen en el navegador.

Relacionado: [[Pendiente]] · [[Reestructuración (iteración Jobber)]] · [[Rutas y planificador (iteración OptimoRoute)]] · [[Guía visual (referencia Holded)]]
