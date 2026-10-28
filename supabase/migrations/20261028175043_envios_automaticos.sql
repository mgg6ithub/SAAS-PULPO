-- DEV-013: envío real de los emails de las automatizaciones.
-- Cada email es una fila de envios_automatizacion (una por destinatario). Las filas las crean:
--   · private.programar_envios(), que mira cada 5 minutos los disparadores por fecha (antes / si no se hace);
--   · triggers, para los que dependen de un hecho (al completarse / al asignar).
-- La clave única evita enviar dos veces el mismo email. La Edge Function «enviar-automatizaciones» manda las pendientes.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net;

create table public.envios_automatizacion (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  automatizacion_id uuid not null references public.automatizaciones (id) on delete cascade,
  trabajo_id uuid not null,
  -- Qué ocasión del trabajo es: la fecha (`2026-11-03`), `hecho:2026-11-03` o `asignado:<trabajador>`.
  ocurrencia text not null,
  destinatario text not null,
  asunto text not null,
  cuerpo text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'enviado', 'simulado', 'error')),
  intentos integer not null default 0,
  error text,
  enviado_en timestamptz,
  created_at timestamptz not null default now(),
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete cascade,
  unique (automatizacion_id, trabajo_id, ocurrencia, destinatario)
);
create index envios_pendientes_idx on public.envios_automatizacion (created_at) where estado in ('pendiente', 'error');
create index envios_empresa_id_idx on public.envios_automatizacion (empresa_id);
create index envios_trabajo_id_idx on public.envios_automatizacion (trabajo_id, empresa_id);
comment on table public.envios_automatizacion is 'Cola y registro de los emails de las automatizaciones: uno por destinatario, sin repetidos.';

alter table public.envios_automatizacion enable row level security;
revoke all on public.envios_automatizacion from anon, authenticated;
grant select on public.envios_automatizacion to authenticated;
create policy envios_select on public.envios_automatizacion for select to authenticated
  using (private.es_admin(empresa_id));

-- ── Crear los envíos de una regla para un trabajo ────────────────────────────
-- p_solo: si viene, de los trabajadores solo ese (al asignar a alguien, solo se le avisa a él).
create function private.encolar_envios(p_automatizacion uuid, p_trabajo uuid, p_ocurrencia text, p_solo uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  with datos as (
    select a.id as auto_id, a.empresa_id, t.id as trabajo_id, a.a_trabajadores, a.a_cliente, a.extras, t.cliente_id,
      coalesce(c.nombre, '') as cliente,
      coalesce(to_char(t.proximo, 'DD/MM/YYYY'), '—') as fecha,
      (select coalesce(string_agg(btrim(w.nombre || ' ' || w.apellidos), ', '), '')
         from public.trabajo_trabajadores tt join public.trabajadores w on w.id = tt.trabajador_id
         where tt.trabajo_id = t.id) as trabajadores,
      t.nombre as trabajo, a.asunto, a.cuerpo
    from public.automatizaciones a
    join public.trabajos t on t.id = p_trabajo and t.empresa_id = a.empresa_id
    left join public.clientes c on c.id = t.cliente_id
    where a.id = p_automatizacion and a.activa
  ),
  para as (
    select d.auto_id, lower(btrim(w.email)) as correo
    from datos d
    join public.trabajo_trabajadores tt on tt.trabajo_id = d.trabajo_id and d.a_trabajadores
    join public.trabajadores w on w.id = tt.trabajador_id and w.activo
    where (p_solo is null or w.id = p_solo)
    union
    select d.auto_id, lower(btrim(c.email)) from datos d join public.clientes c on c.id = d.cliente_id where d.a_cliente
    union
    select d.auto_id, lower(btrim(x)) from datos d, unnest(d.extras) x
  )
  insert into public.envios_automatizacion (empresa_id, automatizacion_id, trabajo_id, ocurrencia, destinatario, asunto, cuerpo)
  select d.empresa_id, d.auto_id, d.trabajo_id, p_ocurrencia, p.correo,
    replace(replace(replace(replace(d.asunto, '{trabajo}', d.trabajo), '{cliente}', d.cliente), '{fecha}', d.fecha),
      '{trabajadores}', d.trabajadores),
    replace(replace(replace(replace(d.cuerpo, '{trabajo}', d.trabajo), '{cliente}', d.cliente), '{fecha}', d.fecha),
      '{trabajadores}', d.trabajadores)
  from datos d join para p on p.auto_id = d.auto_id
  where p.correo like '%_@_%.__%'
  on conflict do nothing;
  get diagnostics n = row_count;
  return n;
end
$$;

-- ── Disparadores por fecha (cada 5 minutos) ──────────────────────────────────
-- Misma cuenta que la vista previa de la app: la hora del trabajo (9:00 si no tiene) menos o más el margen.
-- Solo entran los que vencieron en los últimos 3 días, para no mandar de golpe lo antiguo al activar una regla.
create function private.programar_envios() returns integer language plpgsql security definer set search_path = '' as $$
declare r record; n integer := 0;
begin
  for r in
    select a.id as auto_id, t.id as trabajo_id, t.proximo
    from public.automatizaciones a
    join public.trabajos t on t.id = a.trabajo_id
    cross join lateral (
      select (t.proximo + make_interval(mins => coalesce(t.inicio_min, 540))) at time zone 'Europe/Madrid' as inicio,
        case when a.en_horas then make_interval(hours => a.cantidad) else make_interval(days => a.cantidad) end as margen
    ) h
    where a.activa and a.disparador in (0, 2) and t.activa and not t.plantilla and t.proximo is not null
      and t.estado <> 2
      and now() >= case when a.disparador = 0 then h.inicio - h.margen else h.inicio + h.margen end
      and now() < case when a.disparador = 0 then h.inicio else h.inicio + h.margen + interval '3 days' end
  loop
    n := n + private.encolar_envios(r.auto_id, r.trabajo_id, r.proximo::text);
  end loop;
  return n;
end
$$;

-- ── Disparadores por hecho ───────────────────────────────────────────────────
create function private.envios_al_completar() returns trigger language plpgsql security definer set search_path = '' as $$
declare a record;
begin
  for a in select id from public.automatizaciones where trabajo_id = new.trabajo_id and activa and disparador = 1 loop
    perform private.encolar_envios(a.id, new.trabajo_id, 'hecho:' || new.dia::text);
  end loop;
  return null;
end
$$;
create trigger envios_al_completar after insert on public.trabajo_historial
  for each row execute function private.envios_al_completar();

create function private.envios_al_asignar() returns trigger language plpgsql security definer set search_path = '' as $$
declare a record;
begin
  for a in select id from public.automatizaciones where trabajo_id = new.trabajo_id and activa and disparador = 3 loop
    perform private.encolar_envios(a.id, new.trabajo_id, 'asignado:' || new.trabajador_id::text, new.trabajador_id);
  end loop;
  return null;
end
$$;
create trigger envios_al_asignar after insert on public.trabajo_trabajadores
  for each row execute function private.envios_al_asignar();

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;
-- Estas solo las usan el cron y los triggers; ningún usuario las llama.
revoke execute on function private.encolar_envios(uuid, uuid, text, uuid), private.programar_envios(),
  private.envios_al_completar(), private.envios_al_asignar() from authenticated;

comment on function private.encolar_envios(uuid, uuid, text, uuid) is 'Crea los envíos pendientes de una regla para un trabajo (uno por destinatario, sin repetir).';
comment on function private.programar_envios() is 'Cron: crea los envíos de las reglas por fecha (antes del trabajo / si no se hace) que ya tocan.';
comment on function private.envios_al_completar() is 'Trigger: al anotar un día hecho, envía las reglas «al completarse».';
comment on function private.envios_al_asignar() is 'Trigger: al asignar un trabajador, envía las reglas «al asignar» (solo a él, al cliente y a los extras).';

-- ── Cada 5 minutos: programar y despertar a la función que envía ─────────────
-- La URL y el secreto compartido están en Vault (se crean aparte, no van en git).
select cron.schedule('automatizaciones-envios', '*/5 * * * *', $cron$
  select private.programar_envios();
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
      || '/functions/v1/enviar-automatizaciones',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
$cron$);
