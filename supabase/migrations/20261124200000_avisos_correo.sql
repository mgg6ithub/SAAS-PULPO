-- Pultec: automatizaciones de la empresa (Ajustes generales → Automatizaciones). Cada regla manda un correo a una
-- dirección cuando pasa algo: una incidencia nueva (todas o solo las críticas) o una orden de trabajo completada.
-- Los correos van a la misma cola que el resto (envios_automatizacion) y los manda la función enviar-automatizaciones.

create table public.avisos_correo (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  evento text not null check (evento in ('incidencia', 'incidencia_critica', 'ot_completada')),
  correo text not null check (correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  unique (empresa_id, evento, correo)
);
create index avisos_correo_empresa_id_idx on public.avisos_correo (empresa_id);
comment on table public.avisos_correo is
  'Pultec: reglas de la empresa que mandan un correo a una dirección cuando hay una incidencia o se completa una OT.';

alter table public.avisos_correo enable row level security;
create policy avisos_correo_select on public.avisos_correo for select to authenticated
  using (private.es_admin(empresa_id));
create policy avisos_correo_insert on public.avisos_correo for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy avisos_correo_update on public.avisos_correo for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy avisos_correo_delete on public.avisos_correo for delete to authenticated
  using (private.es_admin(empresa_id));
revoke all on public.avisos_correo from anon;
grant select, insert, update, delete on public.avisos_correo to authenticated;

-- Nombre del activo principal (y del componente, si la incidencia o la OT es de uno): «PST-01 · Planta › Bomba».
create or replace function private.nombre_maquina(p_activo uuid) returns text
language sql stable security definer set search_path = '' as $$
  with recursive arriba as (
    select x.id, x.padre_id from public.activos x where x.id = p_activo
    union all select x.id, x.padre_id from public.activos x join arriba on x.id = arriba.padre_id
  )
  select concat_ws(' › ',
    nullif(btrim(concat_ws(' · ', nullif(r.tag, ''), nullif(r.nombre, ''))), ''),
    case when r.id <> a.id then nullif(btrim(concat_ws(' · ', nullif(a.tag, ''), nullif(a.nombre, ''))), '') end)
  from public.activos a, public.activos r
  where a.id = p_activo and r.id = (select id from arriba where padre_id is null limit 1)
$$;

-- Remitente con el nombre de la empresa, como el resto de correos.
create or replace function private.remitente_empresa(p_empresa uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case when coalesce(btrim(e.nombre), '') = '' then 'Pultec' else 'Pultec · ' || btrim(e.nombre) end
  from public.empresas e where e.id = p_empresa
$$;

-- Incidencia nueva → correo a las reglas «incidencia» y, si es grave, también a «incidencia_critica».
create or replace function private.avisos_incidencia() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.envios_automatizacion
    (empresa_id, incidencia_id, ocurrencia, destinatario, asunto, cuerpo, remitente)
  select distinct on (lower(btrim(v.correo))) new.empresa_id, new.id, 'aviso:incidencia:' || new.id, lower(btrim(v.correo)),
    'Nueva incidencia' || case when new.gravedad = 2 then ' crítica' else '' end
      || ' · ' || coalesce(private.nombre_maquina(new.activo_id), 'activo'),
    concat_ws(E'\n\n',
      'Hay una incidencia' || case when new.gravedad = 2 then ' crítica' else '' end
        || ' en ' || coalesce(private.nombre_maquina(new.activo_id), 'un activo') || '.',
      nullif(btrim(new.descripcion), ''),
      case when cardinality(new.fotos) > 0 then 'Con ' || cardinality(new.fotos) || ' foto(s): míralas en Pultec.' end)
      || E'\n\n—\nTe llega por una automatización de Ajustes generales de Pultec.',
    private.remitente_empresa(new.empresa_id)
  from public.avisos_correo v
  where v.empresa_id = new.empresa_id and v.activa
    and (v.evento = 'incidencia' or (v.evento = 'incidencia_critica' and new.gravedad = 2))
  on conflict do nothing;
  return new;
end $$;

create trigger incidencias_avisos_correo after insert on public.incidencias
  for each row execute function private.avisos_incidencia();

-- OT completada (estado 2) → correo a las reglas «ot_completada» (una vez por OT y dirección).
create or replace function private.avisos_ot_completada() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 2 and old.estado is distinct from 2 then
    insert into public.envios_automatizacion
      (empresa_id, trabajo_id, ocurrencia, destinatario, asunto, cuerpo, remitente)
    select new.empresa_id, new.id, 'aviso:completada:' || new.id, lower(btrim(v.correo)),
      'Orden de trabajo completada · ' || coalesce(nullif(btrim(new.nombre), ''), 'Orden de trabajo'),
      concat_ws(E'\n\n',
        'Se ha completado la orden de trabajo «' || coalesce(nullif(btrim(new.nombre), ''), 'sin nombre') || '»'
          || coalesce(' de ' || private.nombre_maquina(new.activo_id), '') || '.',
        'El parte está en Pultec.')
        || E'\n\n—\nTe llega por una automatización de Ajustes generales de Pultec.',
      private.remitente_empresa(new.empresa_id)
    from public.avisos_correo v
    where v.empresa_id = new.empresa_id and v.activa and v.evento = 'ot_completada'
      and not exists (
        select 1 from public.envios_automatizacion x
        where x.trabajo_id = new.id and x.ocurrencia = 'aviso:completada:' || new.id
          and x.destinatario = lower(btrim(v.correo)));
  end if;
  return new;
end $$;

create trigger trabajos_avisos_correo after update of estado on public.trabajos
  for each row execute function private.avisos_ot_completada();
