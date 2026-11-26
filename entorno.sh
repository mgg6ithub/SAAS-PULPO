#!/usr/bin/env bash
# Entorno de pruebas de Pultec: Supabase local en contenedores + la app con recarga en vivo.
# Producción no se toca: la app en desarrollo apunta a esta Supabase (ver app/tool/vivo.py).
#
#   ./entorno.sh arrancar   Levanta Supabase local en modo LIGERO; si no hay base, la construye con migraciones + seed:
#                           base de datos, login, API, fotos (storage) y en vivo (realtime). Sin Studio, funciones ni emails: ~650 MB.
#                           Al terminar aplica las migraciones pendientes (p. ej. tras un `git pull`), sin borrar datos.
#   ./entorno.sh migrar     Aplica solo las migraciones pendientes a la base local, sin borrar datos.
#   ./entorno.sh completo   Reinicia Supabase con TODO (Studio en localhost:54323, Edge Functions, Mailpit): ~1.3 GB.
#   ./entorno.sh funciones  Sirve las Edge Functions de supabase/functions sobre el modo ligero (Ctrl+C para parar).
#   ./entorno.sh app       Arranca Pultec en http://localhost:8000 contra la Supabase local.
#   ./entorno.sh landing    Sirve la landing en http://localhost:8001 y reenvía ahí la Supabase local (arráncala antes que la app).
#   ./entorno.sh reset      Borra la base LOCAL y la recrea: todas las migraciones de supabase/migrations + supabase/seed.sql.
#   ./entorno.sh estado     URLs y claves locales.
#   ./entorno.sh plan       Plan (básico/premium) de cada cuenta local. Para probar sin pagar:
#                           ./entorno.sh plan correo@x premium|basico  (cambia el plan de la empresa que administra).
#   ./entorno.sh parar      Guarda como migración nueva los cambios de esquema hechos fuera de una migración (p. ej. desde Studio),
#                           para Supabase y BORRA la base local: no queda nada sin cifrar y el próximo `arrancar` la reconstruye
#                           desde supabase/migrations + supabase/seed.sql (así se prueba siempre que las migraciones funcionan).
#                           Los DATOS que metas a mano en local se pierden: lo que deba quedarse va en supabase/seed.sql.
#
# Requisitos: Docker (o podman) y la CLI de Supabase (https://supabase.com/docs/guides/local-development/cli/getting-started).
# Cuentas de prueba (supabase/seed.sql): admin@pultec.local y tecnico@pultec.local, contraseña pultec1234.
set -euo pipefail
cd "$(dirname "$0")"

# Con Docker, la CLI va tal cual. Sin Docker pero con podman, usa el podman de root (sus imágenes caben mejor en disco).
if docker info >/dev/null 2>&1 && ! docker --version 2>/dev/null | grep -qi podman; then
  sb() { supabase "$@"; }
elif command -v podman >/dev/null; then
  # Devuelve el resultado de la CLI (no el del chown), para poder fiarse de si ha fallado.
  sb() {
    local r=0
    sudo DOCKER_HOST=unix:///run/podman/podman.sock "$(command -v supabase)" "$@" || r=$?
    sudo chown -R "$(id -u):$(id -g)" supabase
    return $r
  }
else
  echo "Hace falta Docker o podman." >&2; exit 1
fi

# SQL contra la base LOCAL (contenedor de Postgres de `supabase start`).
sql() {
  local id; id=$(sed -n 's/^project_id = "\(.*\)"/\1/p' supabase/config.toml)
  if docker info >/dev/null 2>&1 && ! docker --version 2>/dev/null | grep -qi podman; then
    docker exec -i "supabase_db_$id" psql -U postgres -v ON_ERROR_STOP=1 -q "$@"
  else
    sudo podman exec -i "supabase_db_$id" psql -U postgres -v ON_ERROR_STOP=1 -q "$@"
  fi
}

# Aplica a la base LOCAL las migraciones que le falten, sin borrar datos. --include-all: al hacer pull pueden llegar
# migraciones con fecha anterior a la última ya aplicada.
migrar() { sb migration up --include-all; }

case "${1:-}" in
  # Sin analíticas (vector, logflare): necesitan el socket de Docker y no hacen falta para probar.
  # Ligero: además fuera Studio + postgres-meta, Edge Functions, Mailpit e imgproxy. Las migraciones son las mismas en los dos modos.
  # `start` no aplica migraciones nuevas si la base ya existe: por eso se migra siempre después.
  arrancar) sb start -x vector,logflare,studio,postgres-meta,edge-runtime,mailpit,imgproxy; migrar ;;
  completo) sb stop; sb start -x vector,logflare; migrar ;;
  migrar)
    # --si-arrancada (lo usa el hook de git): con Supabase parada no hace nada.
    if [ "${2:-}" = --si-arrancada ] && ! sql -c 'select 1' </dev/null >/dev/null 2>&1; then
      echo "Supabase local parada: las migraciones se aplicarán al arrancar."
      exit 0
    fi
    migrar ;;
  funciones) sb functions serve --env-file supabase/.env ;;   # secretos (STRIPE_*) en supabase/.env, fuera de git
  parar)
    # 0. Primero las migraciones pendientes: si no, el `diff` las tomaría por cambios a deshacer.
    if ! migrar; then
      echo "No se pudieron aplicar las migraciones pendientes (¿Supabase no está arrancado?). No borro la base local." >&2
      exit 1
    fi
    # 1. Cambios de esquema sin migración → migración nueva (si no hay cambios, no crea nada).
    antes=$(ls supabase/migrations | wc -l)
    if ! sb db diff -f cambios_sin_migracion; then
      echo "No se pudo comprobar el esquema (¿Supabase no está arrancado?). No borro la base local." >&2
      exit 1
    fi
    if [ "$(ls supabase/migrations | wc -l)" -gt "$antes" ]; then
      echo "⚠  Migración nueva con tus cambios: supabase/migrations/$(ls -t supabase/migrations | head -1)"
      echo "   Revísala y haz commit para que llegue a producción y a los demás equipos."
    fi
    # 2. Para y borra la base local (el próximo `arrancar` la reconstruye).
    sb stop --no-backup ;;
  reset)    sb db reset --local ;;
  plan)     # Solo LOCAL, para pruebas: ver el plan de cada cuenta o cambiarlo sin pagar (sin Stripe).
    if [ -n "${2:-}" ]; then
      [[ "${3:-}" =~ ^(premium|basico)$ ]] || { echo "Uso: ./entorno.sh plan correo premium|basico" >&2; exit 1; }
      sql -v correo="$2" -v plan="$3" <<'SQL'
insert into public.suscripciones (empresa_id, plan, periodo, estado, fin_periodo)
select m.empresa_id, :'plan', 'mensual', case when :'plan' = 'premium' then 'active' end,
       case when :'plan' = 'premium' then now() + interval '1 month' end
from public.miembros m join auth.users u on u.id = m.usuario_id
where u.email = :'correo' and m.rol = 'admin'
on conflict (empresa_id) do update
  set plan = excluded.plan, periodo = excluded.periodo, estado = excluded.estado, fin_periodo = excluded.fin_periodo,
      cancela_al_final = false;
SQL
    fi
    sql <<'SQL'
select u.email as cuenta, m.rol, e.nombre as empresa,
       case when s.plan = 'premium' and s.estado in ('active', 'trialing', 'past_due') then 'PREMIUM' else 'basico' end as plan,
       coalesce(s.estado, '-') as estado_stripe
from auth.users u
left join public.miembros m on m.usuario_id = u.id
left join public.empresas e on e.id = m.empresa_id
left join public.suscripciones s on s.empresa_id = m.empresa_id
order by u.created_at;
SQL
    ;;
  estado)   sb status ;;
  app)
    export PATH="${FLUTTER_BIN:-/usr/local/flutter-sdk/flutter/bin}:$PATH"
    [ -d /srv/flutter-sdk/pub-cache ] && export PUB_CACHE=/srv/flutter-sdk/pub-cache
    # Si la landing (con su pasarela a Supabase) está en marcha, la app usa esa dirección: el navegador solo
    # necesita los puertos 8000 y 8001. Si no, va directa a la Supabase local (:54321).
    if curl -s -o /dev/null --max-time 2 http://localhost:8001/auth/v1/health; then
      export SUPABASE_LOCAL_URL=http://localhost:8001
    fi
    cd app && PUERTO="${PUERTO:-8000}" exec python3 tool/vivo.py --industrial ;;
  landing)  exec python3 tool/landing_local.py ;;   # landing + pasarela a Supabase en :8001
  *) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
