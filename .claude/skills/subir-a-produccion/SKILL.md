---
name: subir-a-produccion
description: Pasa a la Supabase de PRODUCCIÓN de Pultec los cambios de base de datos y Edge Functions probados en la Supabase local. Usar solo cuando el usuario pida subir, pasar o desplegar a producción los cambios de base de datos o funciones.
---

# Subir a producción (Supabase)

En desarrollo se trabaja SIEMPRE contra la Supabase local (`./entorno.sh arrancar`). Producción
(`gvasthxiqckmekwvhtrg`) solo se toca con esta skill, al terminar, y con confirmación expresa del usuario.

## Reglas que no se saltan
- Todo cambio de base de datos va en una migración de `supabase/migrations/` (`supabase migration new <nombre>`).
  Nada de cambios a mano en el panel de producción.
- Nunca: `supabase db reset --linked`, cargar `supabase/seed.sql` en producción, `db push --include-seed`,
  borrar o editar migraciones que ya están en producción, ni `--force`/`repair` sin que el usuario lo pida.
- No se sube nada sin mostrar antes el plan (dry run) y sin un «sí» explícito del usuario en este turno.
- Las claves (token de acceso, contraseña de la base) las pone el usuario en su terminal; no se escriben en el repo.

## Pasos
1. **Comprobar en local.** `./entorno.sh reset` debe aplicar todas las migraciones y el seed sin errores.
   Si hay tests SQL en `supabase/tests/`, `supabase test db` (con el mismo prefijo que usa `entorno.sh`).
   Con cambios en la app, `cd app && flutter analyze` y `flutter test`.
2. **Git limpio.** Las migraciones y funciones a subir tienen que estar en commit (lo que llega a producción
   debe estar en el repo). Si no, parar y decírselo al usuario.
3. **Enlazar el proyecto** (solo la primera vez en cada equipo): pedir al usuario que ejecute
   `supabase login` y `supabase link --project-ref gvasthxiqckmekwvhtrg` (pide la contraseña de la base).
4. **Plan.** `supabase db push --linked --dry-run` → lista de migraciones pendientes. Revisar cada una buscando
   lo destructivo (`drop`, `truncate`, `delete`, cambios de tipo, `not null` sin default en tablas con datos)
   y avisar de ello. Funciones: comparar `supabase/functions/` con `supabase functions list`.
5. **Confirmar.** Enseñar al usuario qué migraciones y funciones se van a subir y los riesgos. Esperar su «sí».
6. **Subir.** `supabase db push --linked`, y por cada función cambiada `supabase functions deploy <nombre>`.
   Los secretos nuevos de las funciones (p. ej. claves de Stripe en modo real) los pone el usuario con
   `supabase secrets set`.
7. **Verificar.** `supabase migration list --linked`: local y remoto coinciden. Contar al usuario qué se ha
   subido y qué queda pendiente (p. ej. publicar la web con `app/tool/build_pages.sh`).
