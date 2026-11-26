-- Pultec: las automatizaciones de la empresa (Ajustes generales → Automatizaciones) se quedan en dos ocasiones:
--   · `incidencia`: cualquier incidencia nueva, de cualquier gravedad (antes había también una solo para críticas);
--   · `ot_vencida`: una orden de trabajo pasa su fecha sin completarse (sustituye a «orden completada»).

-- ── Lo que ya había ──────────────────────────────────────────────────────────
-- Las reglas de «incidencia crítica» pasan a «incidencia» (si ese correo ya estaba, sobra).
delete from public.avisos_correo c
where c.evento = 'incidencia_critica'
  and exists (select 1 from public.avisos_correo x
              where x.empresa_id = c.empresa_id and x.evento = 'incidencia' and x.correo = c.correo);
update public.avisos_correo set evento = 'incidencia' where evento = 'incidencia_critica';
-- «Orden completada» desaparece.
delete from public.avisos_correo where evento = 'ot_completada';

alter table public.avisos_correo drop constraint avisos_correo_evento_check;
alter table public.avisos_correo add constraint avisos_correo_evento_check check (evento in ('incidencia', 'ot_vencida'));
comment on table public.avisos_correo is
  'Pultec: reglas de la empresa que mandan un correo a una dirección cuando hay una incidencia o vence una OT.';

-- ── Incidencias: todas por la misma regla ────────────────────────────────────
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
  where v.empresa_id = new.empresa_id and v.activa and v.evento = 'incidencia'
  on conflict do nothing;
  return new;
end $$;

-- ── Fuera «orden completada» ─────────────────────────────────────────────────
drop trigger if exists trabajos_avisos_correo on public.trabajos;
drop function if exists private.avisos_ot_completada();

-- ── Órdenes vencidas (cron cada 5 minutos) ───────────────────────────────────
-- Vencida = como en la app: OT activa (no plantilla ni subtrabajo), pendiente o en curso, con fecha anterior a hoy
-- (hora de Madrid). Un correo por orden, fecha y dirección; si se le cambia la fecha y vuelve a vencer, otro.
-- Solo las que vencieron en los últimos 3 días, para no mandar de golpe lo antiguo al crear una regla.
create or replace function private.avisos_ot_vencidas() returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  with hoy as (select (now() at time zone 'Europe/Madrid')::date as d)
  insert into public.envios_automatizacion
    (empresa_id, trabajo_id, ocurrencia, destinatario, asunto, cuerpo, remitente)
  select t.empresa_id, t.id, 'aviso:vencida:' || t.id || ':' || t.proximo, lower(btrim(v.correo)),
    'Orden de trabajo vencida · ' || coalesce(nullif(btrim(t.nombre), ''), 'Orden de trabajo'),
    concat_ws(E'\n\n',
      'La orden de trabajo «' || coalesce(nullif(btrim(t.nombre), ''), 'sin nombre') || '»'
        || coalesce(' de ' || private.nombre_maquina(t.activo_id), '')
        || ' tenía que hacerse el ' || to_char(t.proximo, 'DD/MM/YYYY') || ' y sigue sin completarse.',
      'Mírala en Pultec.')
      || E'\n\n—\nTe llega por una automatización de Ajustes generales de Pultec.',
    private.remitente_empresa(t.empresa_id)
  from public.trabajos t
  cross join hoy
  join public.avisos_correo v on v.empresa_id = t.empresa_id and v.activa and v.evento = 'ot_vencida'
  where t.activa and not t.plantilla and t.padre_id is null and t.tipo_mantenimiento is not null
    and t.estado in (0, 1)
    and t.proximo < hoy.d and t.proximo >= hoy.d - 3
    and not exists (
      select 1 from public.envios_automatizacion x
      where x.trabajo_id = t.id and x.ocurrencia = 'aviso:vencida:' || t.id || ':' || t.proximo
        and x.destinatario = lower(btrim(v.correo)));
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function private.avisos_ot_vencidas() from public, anon, authenticated;
comment on function private.avisos_ot_vencidas() is
  'Cron: mete en la cola el correo de las reglas «ot_vencida» por cada OT que acaba de vencer.';

-- Cada 5 minutos, como el resto; la función que envía pasa por la cola en su propia vuelta del cron.
select cron.schedule('avisos-ot-vencidas', '*/5 * * * *', $cron$ select private.avisos_ot_vencidas(); $cron$);
