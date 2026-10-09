---
tags: [ui, diseño, pulpo]
---
# Guía visual: referencia Holded

Fuente: `Grabación 2026-10-07 161626.mp4` (12 min, Holded). He sacado dos capturas por segundo y he quitado las repetidas, las oscurecidas por una transición y las de carga. Han quedado **244 capturas** agrupadas en `capturas/` por tipo de pantalla. Cada archivo se llama por el minuto del vídeo en que aparece (`07m11s5.jpg` = 7:11,5).

| Carpeta | Qué hay | Nº |
|---|---|---|
| `00-seleccion` | Las 41 mejores, una por patrón, con nombre descriptivo (las que se citan abajo con su número) | 41 |
| `01-bienvenida-inicio` | Saludo, acciones rápidas, tarjeta destacada, resúmenes, listas de acciones pendientes | 33 |
| `02-dashboards-kpis` | Tableros de widgets: cuadraditos con cifras, mini barras, puntos de color | 14 |
| `03-graficos-informes` | Curvas, áreas, barras, tooltips, plan financiero, cashflow, tablas jerárquicas | 32 |
| `04-listas-tablas` | Contactos, facturas, presupuestos, servicios, cuadro de cuentas | 36 |
| `05-crear-editar-dialogos` | Nuevo presupuesto, editar contacto (con pestañas), nueva actividad, nueva oportunidad, confirmar borrado, desplegables | 32 |
| `06-fichas-detalle` | Ficha de contacto con pestañas, paneles laterales (contacto, oportunidad, suscripción), documento + panel | 15 |
| `07-kanban-calendario` | Embudo kanban, calendario mensual | 7 |
| `08-catalogo-tarjetas` | Store (rejilla de tarjetas, chips de filtro), asesorías (lista con filtros laterales) | 17 |
| `09-navegacion-menus` | Submenús flotantes, búsqueda global, selector de fechas, tooltips de la barra | 9 |
| `10-estados-vacios-banners` | Pantallas vacías con ilustración, bienvenida a módulos, escáner | 10 |
| `11-ajustes-configuracion` | Perfil de usuario, cuenta, usuarios, emails, portal del cliente (colores, fuente, vista previa) | 39 |

No copiamos Holded. Cogemos su **disciplina visual** y le damos el carácter de Pulpo: el morado y el color propio de cada tipo de mantenimiento.

---

## 1. Estructura general
- **Barra lateral fija (~220 px)** con fondo gris muy claro (`#F7F7F8`) separada del contenido blanco. Arriba: logo + buscar + notificaciones + "+". Debajo, el **selector de empresa** (avatar con iniciales + nombre + ⌄). Luego los apartados, con icono de línea de 16 px y texto de 14 px. El activo lleva fondo gris redondeado. Abajo: "Ayuda y soporte" y el usuario. → `11`
- Los subapartados aparecen al expandir dentro de la barra (Ventas → Facturas, Presupuestos…) o en un **menú flotante** al pasar el ratón. → `11`, `29`
- El **contenido va centrado con ancho máximo** (~930 px) en Inicio y a ancho completo en tablas e informes.
- **Bloque "Descubre más"**: una tarjeta tintada de azul en la barra, con un contador. Sirve de ejemplo de un acento que llama la atención sin gritar.

## 2. Cabecera de página
- Un **título grande en negrita** (24 px) a la izquierda, a veces con un ⓘ.
- A la derecha: iconos fantasma (vista, ajustes) → botón "Acciones ⌄" con borde → **un único botón primario** relleno ("Nuevo contacto", con atajo de teclado `N`). → `12`, `15`
- **Selector segmentado** para las vistas principales (Resumen | Tableros): fondo gris y la opción activa en blanco con sombra suave. → `01`, `08`
- **Pestañas píldora oscuras** para las subvistas (Resumen ⋮ | Proyectos): la activa en negro relleno. → `08`, `33`

## 3. Inicio y dashboard
- **Saludo** ("¡Hola, IKER! 👋") + una línea de ayuda. → `01`
- **Fila de acciones rápidas**: 4 tarjetas horizontales con icono, título y subtítulo. La primera va rellena de color (degradado morado o azul) y las demás en blanco con borde. → `01`
- **Tarjeta destacada** a dos columnas: el texto con viñetas de check verde y dos botones a la izquierda, y una mini-maqueta del producto a la derecha sobre un fondo degradado suave. → `02`
- **Tarjeta de KPIs**: título + selector de periodo ("Últimos 30 días ⌄"), y 3 cifras grandes con etiqueta gris encima y la variación en verde o rojo (▲ 71,7 %). → `03`
- **Listas de "Acciones pendientes"**: icono en un cuadrado tintado, texto, la categoría en gris a la derecha y "›". → `04`
- **Tableros de widgets** en rejilla de 4 columnas, con tarjetas blancas de borde muy fino: título + subtítulo de periodo, una cifra grande y una **mini gráfica de barras azules** con los meses. Los puntos de color (● rojo "Pagos pendientes", ● verde "Entradas") etiquetan las métricas. Algunos widgets tienen listas con barras de progreso. → `08`, `09`
- **Estados vacíos dentro del widget**: una ilustración pequeña y un texto gris centrado ("No tienes tareas asignadas"). → `10`

## 4. Tablas (lo más usado)
- Encima de la tabla, la barra de filtros: un **chip segmentado** (Todos | Empresas | Personas), un desplegable de orden, "+ Filtro" en azul, y a la derecha la búsqueda, el rango de fechas y la exportación. → `12`, `15`
- Las **cabeceras** van en gris claro y pequeñas, con flecha de orden. Las filas miden ~44 px, con separador de 1 px, sin rejilla vertical y con hover gris.
- Primera columna: checkbox + **avatar cuadrado de 2 letras con color** (cada contacto tiene el suyo). → `12`, `22`
- **Pastilla de estado** rellena y pequeña: Cliente/Pagado en verde, Proveedor/Vencido en rojo, Pendiente en ámbar. → `12`, `15`
- Hay **etiquetas de categoría** con un punto de color + texto en una píldora gris ("● Prestaciones de servicio"). → `15`
- A la derecha, iconos de acción y un "⋮" por fila. **Al pie**, los totales en negrita y la paginación "1–12 (12)  50 ⌄". → `16`
- Las **tablas jerárquicas** se pliegan con ▸ y las filas de subtotal van en negrita con fondo gris. → `33`, `36`

## 5. Fichas y detalle
- La **ficha** lleva "←", un avatar, el nombre en 24 px negrita y la pastilla de tipo ("Cliente"). Debajo, las pestañas de texto (Resumen · Ventas · Presupuestos · Pagos · Notas · Archivos). → `14`
- El **documento con panel lateral** se divide en dos: a la izquierda la vista previa y a la derecha un panel con un segmentado oscuro (General | Mensajes | Historial) y pares etiqueta-valor alineados a izquierda y derecha. Los enlaces de acción van en azul a la derecha ("Editar", "Añadir pago"). → `21`
- **Formularios**: etiquetas pequeñas grises encima de campos con borde fino, agrupados en bloques con título ("Método de pago", "Categorización") a dos columnas. Los totales van alineados a la derecha. → `19`, `20`

## 6. Kanban
- Columnas sin fondo. Cada cabecera lleva el título en negrita y debajo, en gris, el importe y el contador ("3 de 4 oportunidades"). → `24`
- Las tarjetas son blancas y planas, con el nombre en negrita, un subtítulo gris, una pastilla de color con el importe y un **avatar redondo** del responsable a la derecha. → `24`, `25`
- "Nueva oportunidad" se abre en un **diálogo** con un segmentado para la etapa del embudo. → `26`

## 7. Calendario
- Una rejilla mensual limpia con líneas de 1 px, el día de hoy tintado de amarillo suave y los eventos como barras finas con borde. Navegación con "Hoy ‹ › Octubre 2026" y la vista "Mes ⌄". → `27`

## 8. Gráficas e informes
- Arriba, **KPIs grandes en fila** separados por líneas finas (Total · Venta media · Margen). → `30`, `29`
- Las **curvas suaves** tienen relleno degradado (azul o verde) y las de áreas apiladas son translúcidas. Los ejes y la rejilla son casi invisibles. → `30`, `32`
- El **tooltip es oscuro** (casi negro), con el mes en mayúsculas y las filas con un punto de color. → `34`, `35`
- La previsión se dibuja en **línea discontinua** después del mes actual. → `33`
- El submenú de informes va en una columna lateral secundaria, con secciones plegables. → `29`

## 8b. Crear y editar (diálogos)
- **Nueva actividad** (`05/10m54s0`): un diálogo a dos columnas. A la izquierda va el día con flechas ‹ ›. A la derecha, el título como campo grande y una **fila de tipos con icono** (Llamada | Reunión | Vuelo…), con el seleccionado relleno en azul. Debajo, las filas de inicio y fin con fecha y hora en azul, y **acciones opcionales como filas tintadas** ("Asignar a", "Enlazar contacto", "Añadir notas") que solo se despliegan si las pulsas. Al pie: "Completada" + "Crear". **Es el modelo directo para "Nueva tarea" en Pulpo**: el tipo de mantenimiento como fila de iconos de color y "Asignar trabajador" como fila opcional.
- **Editar contacto** (`05/02m27s0`–`02m40s5`): un diálogo con pestañas de texto (Básico · Cuentas · Preferencias · Contabilidad), campos a dos columnas y un estado vacío dentro de la pestaña ("Añade el primer banco"). Al pie, "Eliminar" en rojo como texto y "Guardar" en azul.
- **Confirmar borrado**: un diálogo pequeño con ilustración, botón rojo relleno y "Cancelar" en rosa suave.
- **Personalizar inicio**: interruptores para mostrar u ocultar los widgets, más "Restaurar" y "Guardar".

## 8c. Ajustes y configuración
- Se abren en un **panel lateral ancho** que entra por la derecha sobre la página. Arriba lleva la etiqueta "CONFIGURACIÓN" en azul y en mayúsculas, el nombre de la empresa, y a la derecha "Cancelar" + "Guardar" + ✕. → `11/`
- Las secciones van en **tarjetas con título y una línea de descripción**, y cada campo en una fila etiqueta-valor.
- Hay un **índice de ajustes** (Cuenta · Facturación · Desarrolladores · Más) con icono y descripción, y migas de pan ("Configuración › Cuenta › Usuarios").
- **Apariencia del portal** (`11/08m10s5`): fuente, redondeo de bordes, **círculos de color del tema** y una **vista previa en vivo**. Es justo lo que tenemos en Ajustes de Pulpo (el color de acento) y nos sirve de referencia para mejorarlo.

## 9. Otros patrones
- **Banner promocional oscuro** (azul marino) de ancho completo: icono, título en negrita, una línea de texto, un botón blanco y ✕. → `18`
- **Cabecera de acción con color** (Escáner): una franja ancha en degradado morado + mini-KPIs con iconos. → `23`
- **Rejilla de tarjetas** (Store): icono pequeño, nombre, descripción gris de 2 líneas y el precio arriba a la derecha en azul. Hay chips de filtro y el activo va en azul relleno. → `39`, `40`
- **Lista con filtros laterales** (Asesorías): checkboxes agrupados a la izquierda y tarjetas con logo y badges de nivel (Silver/Gold) a la derecha. → `41`
- **Puntos de color** como código visual mínimo (cuadro de cuentas). → `37`
- **Estado vacío grande**: una ilustración circular gris, título, viñetas y un botón primario. → `38`

---

## Cómo lo llevamos a Pulpo
| Holded | Pulpo |
|---|---|
| Azul primario | **Morado** del logo (acento de Ajustes) |
| Fila de acciones rápidas (la 1.ª rellena) | "Nueva tarea" (morado) · Nuevo cliente · Añadir trabajador · Planificar semana |
| Tarjeta de KPIs con variación | Tareas hoy · Vencidas · Hechas este mes, con ▲▼ frente al mes anterior |
| Acciones pendientes | "3 tareas vencidas", "2 tareas sin trabajador", "1 cliente sin equipos" |
| Tableros de widgets | Carga por trabajador, mantenimientos por tipo, próximos 7 días |
| Tabla de contactos con avatar de color y pastilla | Clientes y trabajadores |
| Pastilla de estado de factura | Estado de tarea: al día / pronto / vencida / hecha |
| Píldora con punto de color | **Tipo de mantenimiento** (● Caldera naranja, ● Ascensor azul…) |
| Ficha con pestañas | Cliente: Resumen · Equipos · Tareas · Historial · Archivos |
| Documento + panel lateral | Detalle de tarea: el checklist a la izquierda y los datos, el historial y las notas a la derecha |
| Kanban de oportunidades | Tablero de tareas por estado o por trabajador, con avatar redondo |
| Calendario mensual | Vista calendario de mantenimientos (barras con el color del tipo) |
| Informes con curvas y tooltip oscuro | Inteligencia: tiempos reales frente a previstos, retrasos por tipo |
| Banner oscuro | Avisos del pulpo ("El pulpo ha propuesto 5 asignaciones →") |

## Reglas
0. **Cuantos menos iconos, mejor.** Sin emojis decorativos (el 🐙 solo en el logo). Botones solo con texto. El tipo de mantenimiento se marca con una barrita o un punto de su color, no con icono; el icono de tipo solo en el selector del formulario. Iconos permitidos: navegación de la barra lateral, cifras clave (KPIs) y acciones de una sola pieza (cerrar, flechas).
1. **Un solo botón primario** por pantalla. El resto, con borde o fantasma.
2. El contenido va en **blanco** y la barra lateral en gris muy claro. Bordes de 1 px `#ECECEF` y sombras casi nulas.
3. **El color informa, no decora**: se usa en el estado, el tipo, el avatar, la acción principal y las gráficas.
4. **Jerarquía por peso**: los títulos en negrita, las etiquetas en gris pequeño encima del valor y las cifras grandes.
5. **Densidad alta** en tablas y aire en Inicio.
6. **Tooltips y banners oscuros** para destacar sobre tanto blanco.
7. Iconos de línea finos y del mismo grosor en toda la app.
