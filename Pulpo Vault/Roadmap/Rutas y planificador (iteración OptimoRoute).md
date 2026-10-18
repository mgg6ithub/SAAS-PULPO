---
tags: [roadmap, pulpo, mapa, rutas, decision]
---
# Rutas y planificador: iteración OptimoRoute

Fuente: los dos vídeos de `Prototipo/OPTIMO RUTOE EJEMPLO/` (10 + 7 min). Hay **233 capturas** en `Interfaz UI/capturas-optimoroute/`, citadas como `carpeta/vídeo_minuto` (p. ej. `07/v2_05m41s5`).
**Copiamos la funcionalidad, no la interfaz.** El estilo sigue siendo el de [[Guía visual (referencia Holded)]]. Continúa la [[Reestructuración (iteración Jobber)]], que ya dejó la Agenda con su mapa.

| Carpeta | Qué hay | Nº |
|---|---|---|
| `01-configuracion-inicial` | Alta: depósito (punto de salida) y tipo de negocio | 3 |
| `02-mapa-capas` | Capas del mapa (estándar, satélite, relieve…), opciones de visualización, zoom | 28 |
| `03-importar` | Importar pedidos: arrastrar CSV/Excel o pegar direcciones | 5 |
| `04-crear-editar-tarea` | Ventana "Añadir pedido" con sus pestañas, edición en lote | 34 |
| `05-tareas-en-mapa` | Tareas como chinchetas, selección, tabla inferior | 52 |
| `06-planificar-rutas` | "Planning Settings": técnicos, horarios, vehículos, equilibrio | 9 |
| `07-rutas-optimizadas` | Rutas dibujadas por técnico (cada una de un color), numeración de paradas | 61 |
| `08-linea-tiempo` | Línea de tiempo por técnico: paradas, desplazamientos y huecos | 33 |
| `09-live-analitica` | Seguimiento en vivo y analítica (estado, puntualidad) | 8 |

## Cómo funciona OptimoRoute (el flujo)
1. **Depósito**: el punto de salida y vuelta de las rutas. → `01/v1_00m01s5`
2. **Pedidos (tareas)**: se crean a mano o se **importan** de un CSV/Excel o pegando direcciones. → `03/v1_01m32s5`
3. Cada pedido lleva: **tipo** (tarea / entrega / recogida), **ubicación**, **duración**, **prioridad** (baja · media · alta · crítica), **ventana horaria** ("solo de 10:00 a 10:30"), **habilidades** requeridas, **características del vehículo**, notas, **asignación manual** opcional y casilla de "planificar a mano". → `04/v1_01m50s0`
4. Se eligen los **técnicos disponibles** del día, cada uno con su horario (de 8:00 a 16:00), su vehículo y la duración de su jornada. Opciones: **equilibrar** la carga entre técnicos y **volver al depósito** para hacer más paradas. → `06/v2_05m37s5`
5. **Planificar rutas**: el optimizador reparte las tareas y ordena las paradas respetando habilidades, ventanas, prioridad y horario. ("Optimization running…") → `07/v1_09m06s0`
6. Resultado: en el mapa, **una ruta de color por técnico** con las paradas numeradas; a la izquierda, cada técnico con su número de pedidos, horas y km. Lo que no cabe queda en **"Sin programar"**. Se puede **deshacer**. → `07/v2_05m41s5`
7. **Línea de tiempo**: una fila por técnico con los bloques de cada parada, los desplazamientos y los huecos libres. → `08/v2_06m09s5`
8. **Live**: seguimiento en el día y **analítica** (estado de los pedidos, puntualidad de llegada). → `09/v1_01m01s5`

## Lo que nos llevamos
- **El optimizador**: es el gran salto del "pulpo mágico". Ahora solo asigna técnico; pasaría a decidir **quién, cuándo y en qué orden**.
- **Restricciones por tarea**: habilidades (ya tenemos *competencias*), ventana horaria, prioridad o criticidad y duración.
- **Restricciones por técnico**: horario laboral, punto de salida (depósito o casa) y carga máxima.
- **Rutas dibujadas por técnico** con orden de paradas y km/tiempo totales.
- **"Sin programar"** con el motivo (sin técnico apto, no cabe en el horario, fuera de ventana).
- **Importación masiva** (CSV/Excel o pegar direcciones), con geocodificación automática.
- **Edición en lote**: seleccionar varias tareas y cambiarles la fecha, el técnico, la prioridad…
- **Selección desde el mapa**: chinchetas que se seleccionan y se sincronizan con la tabla.

## Lo que NO copiamos
- La interfaz: tablas grises densísimas, iconos diminutos, ventanas con 8 pestañas laterales, chat y banners de prueba.
- La terminología de reparto ("pedido", "vehículo", "carga"): en Pulpo son **tareas/visitas, técnicos y competencias**.
- Pantallas separadas Plan / Live / Analytics: lo integramos en la Agenda y en Inicio.

## Modelo de datos (añadidos)
| Entidad | Campos nuevos |
|---|---|
| **Tarea / Visita** | `criticidad` (enum: baja · media · alta · crítica), `ventanaDesde` / `ventanaHasta` (franja en la que se puede hacer), `duracionMin` (ya existe), `competencias` (ya existe), `fijada` (no la mueve el optimizador), `ordenEnRuta`, `motivoSinProgramar` |
| **Trabajador** | `horaInicio` / `horaFin`, `puntoSalida` (lat/lng: depósito o casa), `maxVisitasDia` |
| **Empresa** | `deposito` (lat/lng y dirección) |
| **Ruta** (nueva, calculada) | técnico, día, paradas en orden, km y minutos totales, geometría para dibujarla |

## Cómo lo hacemos técnicamente
- **Optimizador v1, en la propia app** (sin servicios externos): voraz más mejora local, con estas reglas:
  1. ordenar por criticidad y después por ventana horaria más estrecha;
  2. por cada tarea, elegir técnicos **aptos** (competencias) con hueco en su horario;
  3. insertarla en la posición de su ruta que **menos distancia añada** y respete las ventanas;
  4. mejorar con 2-opt; lo que no entra va a **Sin programar** con su motivo.
- **Distancias**: en la v1 en línea recta (haversine) a una velocidad media; en la v2, tiempos reales por carretera con **OSRM** (gratis y de código abierto; tiene servidor de demostración y se puede montar uno propio).
- **Dibujo de rutas**: en la v1 polilíneas rectas entre paradas (como hace OptimoRoute en sus capturas); en la v2, la geometría real que devuelve OSRM.
- **Importar**: CSV/Excel (cliente, dirección, tipo, duración, criticidad, ventana) → geocodificar con Nominatim → vista previa con errores antes de guardar.

## Checklist del mapa y las rutas
Prioridad: **P1** = siguiente · **P2** = después · **P3** = más adelante.

**Modelo**
- [ ] P1 · `criticidad` (enum de 4 niveles) en tareas, con su pastilla de color.
- [ ] P1 · `ventana horaria` (desde–hasta) en tareas.
- [ ] P1 · Horario laboral y punto de salida por técnico; depósito de la empresa.
- [ ] P2 · `fijada`: tareas que el optimizador no puede mover.

**Planificar**
- [ ] P1 · Botón **"Planificar rutas"** en la Agenda (día elegido): ventana con los técnicos disponibles (activar/desactivar, horario) y las opciones de equilibrar y volver al depósito.
- [ ] P1 · Optimizador v1 (competencias + ventana + criticidad + horario + distancia).
- [ ] P1 · Panel **"Sin programar"** con el motivo de cada tarea.
- [ ] P1 · **Deshacer** la última planificación.
- [ ] P2 · Replanificar solo lo nuevo sin tocar lo ya asignado ("cambios permitidos").
- [ ] P3 · Distancias y tiempos reales por carretera (OSRM).

**Mapa**
- [ ] P1 · **Rutas dibujadas por técnico** (color del técnico) con paradas numeradas y el depósito.
- [ ] P1 · Lista lateral de técnicos con nº de visitas, horas y km; al pulsar uno se resalta su ruta.
- [ ] P2 · Seleccionar tareas en el mapa (clic o lazo), sincronizado con la lista.
- [ ] P2 · Capas del mapa: estándar / satélite / relieve.
- [ ] P3 · Arrastrar una parada a otra ruta o cambiar su orden.

**Línea de tiempo**
- [ ] P1 · La vista **Día por técnico** de la Agenda muestra también los **desplazamientos** (bloques rayados) entre visitas.
- [ ] P2 · Huecos libres resaltados; arrastrar una visita a un hueco.

**Crear e importar**
- [ ] P1 · En "Nueva tarea": criticidad, ventana horaria y duración, siguiendo la regla de menos iconos.
- [ ] P2 · **Importar CSV/Excel** o pegar direcciones, con vista previa y errores.
- [ ] P2 · Edición en lote (fecha, técnico, criticidad) desde la tabla de Mantenimientos.

**Seguimiento**
- [ ] P3 · Estado en vivo del día (pendiente / en camino / hecha) y puntualidad.
- [ ] P3 · Compartir la ruta con el técnico (enlace o app) y avisar al cliente de la hora.

Relacionado: [[Reestructuración (iteración Jobber)]] · [[Pendiente]] · [[Guía visual (referencia Holded)]]
