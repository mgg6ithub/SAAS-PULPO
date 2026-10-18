---
tags: [roadmap, pulpo, ui, decision]
---
# Reestructuración: iteración Jobber

Fuente: `Prototipo/JOBBER ejemplo/2026-10-15 19-47-32.mp4` (6 min). Hay **133 fotogramas** agrupados en `Interfaz UI/capturas-jobber/`. Se citan abajo por `grupo/minuto` (p. ej. `03/00m35s5`).
Complementa a [[Guía visual (referencia Holded)]]: **Holded nos da el estilo; Jobber nos da el flujo de trabajo.**

## Qué hace bien Jobber
- **Un flujo lineal y claro:** Cliente → Solicitud → Trabajo → **Visita** → Factura. Cada paso se crea desde el anterior ("Convertir en trabajo") y arrastra los datos.
- **Agenda (Schedule)** con selector **Mes / Semana / Día** y botón **Mapa** que abre un mapa a la derecha con los trabajos del periodo. → `03/00m35s5`, `03/05m38s0`
- **Vista Día por técnico:** una fila por trabajador (y otra para "Sin asignar") sobre una línea de horas horizontal. → `03/00m29s0`
- **Crear desde la agenda:** al pulsar en un hueco aparece una ventanita con Trabajo / Solicitud / Tarea / Evento, cliente, título, asignar, duración y un interruptor "Mostrar disponibilidad". → `03/00m22s0`
- **"Find a time":** busca el primer hueco libre del equipo.
- **Ficha de visita en ventanita:** casilla de completada, equipo, ubicación, conceptos y botones *Buscar hueco · Editar · Detalles*. → `03/04m21s5`
- **Nuevo cliente en una sola página:** contacto arriba y **dirección de la propiedad** aparte (con autocompletado), más secciones plegables. → `05/01m27s0`
- **Ficha de cliente:** Propiedades · Contactos · **Resumen del trabajo filtrable** (solicitudes, presupuestos, trabajos, facturas) · Agenda del cliente · Notas, más un resumen económico y las etiquetas a la derecha. → `06/01m50s5`
- **Visitas únicas o recurrentes** al crear un trabajo, más la checklist "capturar datos en la visita". → `05/03m40s0`
- **Evaluación previa (on-site assessment)** dentro de la solicitud: fecha, técnico y checklist. → `05/02m55s0`
- Listas con **3 cifras arriba** (nuevos, recientes, totales) y la tabla debajo. → `04/03m21s0`
- Modo oscuro completo y ajustes de agenda (días laborables, colores). → `11/00m48s5`

## Lo que no nos gusta (y evitamos)
- Demasiados módulos de pago o vacíos (Marketing, Pipeline, Insights, Expenses) que ensucian el menú. → `10/`
- Barra lateral **solo con iconos**: no se sabe qué es cada cosa sin pasar el ratón.
- Banners, chat flotante y ventanas de "mejora tu plan" encima del trabajo.
- Mucha facturación y presupuestos: no es nuestro foco, porque Pulpo es **mantenimiento preventivo recurrente**.
- Formularios muy largos (la solicitud tiene 6 bloques).

## Modelo de datos: cómo nos cambia
Jobber separa **lo que hay que hacer** (trabajo) de **cada vez que se va** (visita). Nos falta justo eso, y resuelve el pendiente del historial.

| Hoy en Pulpo | Propuesta |
|---|---|
| Cliente con una dirección | Cliente → **Ubicaciones** (edificios/propiedades con dirección y coordenadas) |
| Tarea = equipo + periodicidad + próximo | **Mantenimiento** (plan recurrente sobre un equipo de una ubicación) |
| Solo se guarda `último` y `próximo` | **Visita**: cada ocurrencia con fecha, hora, técnico(s), estado, checklist, notas y fotos → **historial real** |
| Plantillas | Plantillas de mantenimiento, con su **checklist** |

## Estructura propuesta de la app
1. **Inicio**: lo que hay hoy.
2. **Agenda**: sustituye a Planificación. Mes · Semana · Día, cada una con **mapa lateral opcional**. La vista Día va por técnico.
3. **Clientes** → ficha con Ubicaciones · Mantenimientos · Historial de visitas · Datos.
4. **Equipo** (trabajadores): su agenda y su carga.
5. **Mantenimientos**: planes y plantillas, con la tabla actual.
6. Ajustes: horario laboral, tipos, competencias y checklists.

## Checklist de lo que aplicamos

> 2026-10-15 · Hecho: Agenda (Día por técnico, Semana por horas, Mes, Tablero) con mapa lateral de OpenStreetMap y chinchetas por cliente; los clientes se ubican solos al guardar su dirección (Nominatim). También: barra lateral oscura (identidad Pulpo) con ancho ajustable, títulos en Plus Jakarta Sans y Tareas renombrada a **Mantenimientos**.
Prioridad: **P1** = siguiente iteración · **P2** = después · **P3** = más adelante.

**Agenda y mapa**
- [x] P1 · Renombrar Planificación → **Agenda**, con selector Mes / Semana / Día.
- [x] P1 · **Botón Mapa**: panel derecho con las visitas del periodo como chinchetas del color del tipo. (Necesita coordenadas: geocodificar la dirección.)
- [x] P1 · **Vista Día por técnico**: filas por trabajador más "Sin asignar", con línea de horas.
- [x] P1 · Vista Semana con columnas por día y bloques por hora.
- [ ] P2 · **Crear desde un hueco** de la agenda (ventanita rápida: cliente, mantenimiento, técnico, hora, duración).
- [ ] P2 · **Buscar hueco**: primer hueco libre de un técnico apto (lo hace el pulpo).
- [ ] P2 · Arrastrar una visita para cambiarla de día u hora.
- [ ] P3 · Ruta del día en el mapa, en orden y con tiempos.

**Modelo**
- [ ] P1 · Entidad **Visita** con historial (fecha, hora, técnicos, estado, notas). Migrar `ultimo` a visitas pasadas.
- [ ] P1 · **Ubicaciones** del cliente (varias direcciones por cliente).
- [ ] P2 · **Checklists** por plantilla, que se rellenan en la visita.
- [ ] P3 · Fotos y firma del cliente en la visita (pensando en la app del técnico).

**Clientes**
- [ ] P1 · Alta de cliente en una página: contacto y **dirección con autocompletado**.
- [ ] P2 · En la ficha, una pestaña **Historial** con las visitas hechas y un resumen filtrable por estado.
- [ ] P2 · Varios contactos por cliente (administrador, conserje…).

**Ventanas rápidas**
- [ ] P2 · Ficha de visita en ventanita: completada · técnico · ubicación · *Buscar hueco · Editar · Detalles*.
- [ ] P2 · "Marcar como hecha" desde la ventanita, que crea la siguiente visita automáticamente.

**Listas**
- [ ] P2 · Tres cifras encima de cada tabla (nuevos 30 días, vencidos, totales).

**Lo que NO copiamos**
- Barra lateral solo con iconos (la nuestra lleva texto), módulos vacíos o de pago, banners y chat flotante, ni la facturación por ahora.

Relacionado: [[Pendiente]] · [[Guía visual (referencia Holded)]] · [[MOC - Prototipo]]
