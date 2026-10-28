# Pulpo

SaaS de automatización de mantenimiento para empresas pequeñas de mantenimiento (ascensores, contra incendios…). Gestiona sus clientes (edificios, colegios, hospitales…), sus trabajadores, qué tareas puede hacer cada uno y cuándo toca cada mantenimiento. Objetivo: automatizar el mantenimiento y ganar inteligencia con los datos.

- Nombre provisional "Pulpo" (logo: pulpo morado).
- Documentación y plan: Cerebro, `~/Desktop/CEREBRO/Proyectos/Pulpo/` → empezar por `MOC - Pulpo.md` y `Producto/Plan general.md` (fuente: `Plan_PULPO_PULTEC.pdf`).
- Para documentar usa la skill `documentar-pulpo`.
- Stack: Flutter desde el prototipo (web primero; SDK en `C:\Users\mgg\flutter`), proyecto en `app/`; datos en local y Supabase después.
- UI: minimalista pero muy funcional, visual y con color.
- Idioma de documentación: español.

## Interfaz: coherencia visual obligatoria
Antes de implementar, cambiar o crear cualquier vista:
- Lee `~/Desktop/CEREBRO/Proyectos/Pulpo/Apariencia/MOC - Apariencia.md` (sistema, componentes, vistas de referencia y reglas) con la skill `pulpo-coherencia-visual`.
- Estilo = demo de la landing (`landing/`): tarjetas blancas de borde fino sin sombra, tinta + morado del logo, Geist, mucho aire, pocos botones.
- Solo tokens de `app/lib/theme.dart` (`P`, `margenPagina`) y componentes de `app/lib/widgets.dart`; nada de valores sueltos. Formularios con `VentanaFormulario` + `Bloque`.
- Pensado para portátil 1080p: lo importante (calendario, mapa) ocupa el alto.
- **Cuantos menos iconos, mejor**: el color (puntos, barritas) sustituye al icono.
- Probar en vivo: `cd app && python3 tool/vivo.py` (localhost:8080, recarga al guardar).
- Jobber y OptimoRoute (`Producto/Referencias/` en Cerebro) son referencia de funcionalidad, no de estilo.
