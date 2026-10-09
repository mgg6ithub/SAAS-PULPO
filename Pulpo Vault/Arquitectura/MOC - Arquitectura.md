---
tags: [moc, arquitectura]
---
# MOC - Arquitectura

## Qué es y para qué sirve
Stack y decisiones técnicas de Pulpo. Sirve para saber con qué se construye cada fase y por qué.

## Stack
- **App:** **Flutter** desde el prototipo. Primero web; después Android, iOS…
- **SDK:** `C:\Users\mgg\flutter` (rama stable). Proyecto en `Pulpo\app\`.
- **Datos:** en local para el prototipo; Supabase después.
- **Hosting del prototipo:** Cloudflare Pages / GitHub Pages (`flutter build web`).
- **UI:** minimalista al estilo Holded; morado como color principal; color por tipo de tarea.
- **Backend:** **Supabase** (PostgreSQL), probablemente con su API REST (PostgREST). No es definitivo.

## Modelo de datos inicial (borrador)
Edificio · Empresa · Trabajador (pertenece a una Empresa) · Tipo de tarea · Capacidad (Trabajador ↔ Tipo de tarea) · Tarea (en un Edificio, de un Tipo, asignada a Empresa/Trabajador).

## Notas
— aún ninguna

## Archivos clave
— aún no hay código
