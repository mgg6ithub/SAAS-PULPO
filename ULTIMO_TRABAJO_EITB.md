# Último trabajo desde EITB (26/11/2026)

Todo el trabajo del día está en el commit «Historial con deshacer por acción, informe de estadísticas…».
`main`, `develop` y `produccion` apuntan a él en el equipo de EITB.

## Pendiente

### 1. Subir a GitHub (desde EITB)
El equipo de EITB no tiene credenciales de GitHub. En el terminal de VS Code (usa la sesión de GitHub del PC):

```
cd ~/Privado/SAAS-PULPO && git push origin main develop produccion
```

O «Sincronizar» en Control de código fuente. Las tres ramas avanzan sin mezclas.

### 2. Subir la base de datos a producción (desde casa)
En el PC de casa, tras `git pull`:

```
supabase login
supabase link --project-ref gvasthxiqckmekwvhtrg
supabase db push --linked --dry-run   # mirar qué entra
supabase db push --linked             # subir
supabase migration list --linked      # local y remoto iguales
```

Migraciones nuevas de este día:
- `20261126100000_columnas_por_usuario.sql`: columnas de cada tabla guardadas por cuenta. Sin riesgo.
- `20261126150000_automatizaciones_dos.sql`: las automatizaciones de empresa se quedan en dos, «incidencia»
  (cualquier gravedad) y «OT vencida» (cron cada 5 min).
  **Ojo:** borra las reglas de «orden completada» y pasa las de «incidencia crítica» a «incidencia».

Puede que también entren migraciones de días anteriores que aún no estaban en producción: el `--dry-run` lo dice.
No hay cambios en Edge Functions.

### 3. Publicar la web
Después de subir la base: `app/tool/build_pages.sh`.

## Tests que fallan (no bloquean la subida)
- Casi todos ya fallaban antes de este día: reglas que cambiaron a propósito y tests que no se actualizaron
  (p. ej. borrar un activo ahora borra sus OT; las OT libres ya no van por categoría).
- Sin revisar: «Históricos: OT realizadas con filtros a 700 px» (`industrial_test.dart`) y repasar
  `columnas_test.dart` tras cambiar su texto a «Restaurar».
- `supabase/tests/tecnico_industrial.sql` comprueba la regla vieja de OT por categoría: hay que ponerlo al día.
