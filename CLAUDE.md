# Pulpo

SaaS de automatización de mantenimiento para empresas pequeñas de mantenimiento (ascensores, contra incendios…). Gestiona sus clientes (edificios, colegios, hospitales…), sus trabajadores, qué tareas puede hacer cada uno y cuándo toca cada mantenimiento. Objetivo: automatizar el mantenimiento y ganar inteligencia con los datos.

- Nombre provisional "Pulpo" (logo: pulpo morado).
- Bóveda: `Pulpo Vault/` → empezar por `MOC - Pulpo.md` y `Roadmap/Pendiente.md`.
- Para documentar usa la skill `documentar-pulpo`.
- Stack: Flutter desde el prototipo (web primero; SDK en `C:\Users\mgg\flutter`), proyecto en `app/`; datos en local y Supabase después.
- UI: minimalista pero muy funcional, visual y con color.
- Idioma de documentación: español.

## Interfaz: referencia visual obligatoria
Antes de implementar, cambiar o crear cualquier vista:
- Lee `Pulpo Vault/Interfaz UI/Guía visual (referencia Holded).md` (reglas y patrones).
- Mira las capturas de referencia del grupo que toque en `Pulpo Vault/Interfaz UI/capturas/` (`00-seleccion` primero; luego `01-bienvenida-inicio`, `02-dashboards-kpis`, `03-graficos-informes`, `04-listas-tablas`, `05-crear-editar-dialogos`, `06-fichas-detalle`, `07-kanban-calendario`, `08-catalogo-tarjetas`, `09-navegacion-menus`, `10-estados-vacios-banners`, `11-ajustes-configuracion`).
- Para flujos de trabajo (agenda, clientes → trabajos → visitas) mira `Pulpo Vault/Interfaz UI/capturas-jobber/` y `Pulpo Vault/Roadmap/Reestructuración (iteración Jobber).md`.
- Para el mapa, rutas y planificador mira `Pulpo Vault/Interfaz UI/capturas-optimoroute/` y `Pulpo Vault/Roadmap/Rutas y planificador (iteración OptimoRoute).md` (solo la funcionalidad, no su interfaz).
- Mira también cómo está ya nuestra app en `Pulpo Vault/Interfaz UI/capturas-pulpo/` para mantener la coherencia.
- **Cuantos menos iconos, mejor**: nada de emojis decorativos ni iconos en botones; el color (puntos, barritas) sustituye al icono. Ver regla 0 de la guía.
- Holded es la musa, no una plantilla: cogemos su disciplina visual, con carácter propio (morado + color por tipo de mantenimiento).
- Al terminar un cambio visual, actualiza `capturas-pulpo/` con capturas nuevas (ver la skill `documentar-pulpo`).
