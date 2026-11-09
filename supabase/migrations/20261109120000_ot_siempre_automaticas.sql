-- Pultec: cada mantenimiento activo tiene siempre una OT pendiente, creada sola.
--  · al crear (o reactivar / reprogramar) un mantenimiento sin OT abierta → su OT con la fecha estimada;
--  · al cerrar la OT de un mantenimiento → la siguiente (la base ya reinicia el mantenimiento antes);
--  · el cron horario queda de red de seguridad. Ya no depende del ajuste de empresa (siempre automático).

-- Fecha estimada del mantenimiento (misma cuenta que la app, `proximoPlan`):
-- fecha puesta → esa; por días → último (o hoy) + días; por horas → el día en que se llega con el uso.
create or replace function private.proximo_estimado(p public.planes_mantenimiento) returns date
language plpgsql stable set search_path = '' as $$
declare
  a public.activos;
  r public.activos;
  quedan numeric;
  ritmo numeric;
  d date;
begin
  if p.proximo is not null then return p.proximo; end if;
  if p.cada_dias is not null then return coalesce(p.ultimo, current_date) + p.cada_dias; end if;
  if p.cada_horas is null then return null; end if;
  select * into a from public.activos where id = p.activo_id;
  if a.id is null then return null; end if;
  r := coalesce(private.raiz(a.id), a);
  quedan := p.cada_horas - (private.horas_hoy(a) - coalesce(p.ultimo_horas, 0));
  if quedan <= 0 then return current_date; end if;
  if r.uso_planificado then
    for i in 1..400 loop
      d := current_date + i;
      quedan := quedan - coalesce((r.turnos ->> to_char(d, 'YYYY-MM-DD'))::numeric, 0) * coalesce(r.horas_turno, 8);
      if quedan <= 0 then return d; end if;
    end loop;
    return null;
  end if;
  ritmo := case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end;
  if coalesce(ritmo, 0) <= 0 then return null; end if;
  return current_date + ceil(quedan / ritmo)::integer;
end $$;

-- Crea la OT pendiente de un mantenimiento si no tiene ninguna abierta. Devuelve su id (null si no hace falta).
create or replace function private.asegurar_ot(id_plan uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  r public.planes_mantenimiento;
  emp uuid;
  nueva uuid;
  tecnico uuid;
begin
  select * into r from public.planes_mantenimiento where id = id_plan;
  if r.id is null or not r.activa then return null; end if;
  if exists (select 1 from public.trabajos t where t.plan_id = r.id and t.activa and t.estado in (0, 1)) then
    return null;
  end if;
  select a.empresa_id into emp from public.activos a where a.id = r.activo_id;
  if emp is null then return null; end if;
  nueva := gen_random_uuid();
  insert into public.trabajos (
    id, empresa_id, activo_id, plan_id, nombre, plantilla, proximo, periodicidad, criticidad,
    duracion_min, estado, activa, competencias, tipo_mantenimiento, notas
  ) values (
    nueva, emp, r.activo_id, r.id,
    r.nombre || case when r.subcontratado then ' (subcontratado)' else '' end,
    false, private.proximo_estimado(r), 5, 3, r.duracion_min, 0, true,
    case when r.categoria <> '' and not r.subcontratado then array[r.categoria] else array[]::text[] end,
    0,
    concat_ws(e'\n\n',
      nullif(case when r.subcontratado then 'Lo hace una empresa externa: ' || nullif(r.empresa_externa, '') end, ''),
      nullif(r.procedimiento, ''),
      nullif('Repuestos: ' || nullif(r.repuestos, ''), ''),
      nullif('Preparar: ' || nullif(r.preparar, ''), ''))
  );
  -- Técnico: solo si hay uno único de su categoría (los grupos llegarán después).
  if not r.subcontratado and r.categoria <> '' then
    select min(w.id::text)::uuid into tecnico
    from public.trabajadores w
    where w.empresa_id = emp and w.activo and r.categoria = any (w.competencias)
    having count(*) = 1;
    if tecnico is not null then
      insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (nueva, tecnico, emp);
    end if;
  end if;
  return nueva;
end $$;

-- Al crear o cambiar un mantenimiento.
create or replace function private.plan_asegura_ot() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.asegurar_ot(new.id);
  return new;
end $$;

drop trigger if exists planes_asegura_ot on public.planes_mantenimiento;
create trigger planes_asegura_ot after insert or update of activa, cada_dias, cada_horas, proximo
  on public.planes_mantenimiento
  for each row execute function private.plan_asegura_ot();

-- Al cerrar la OT de un mantenimiento: la siguiente (tras el reinicio que hace `al_cerrar_ot`).
create or replace function private.ot_cerrada_siguiente() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.plan_id is not null and new.estado = 2 and old.estado is distinct from 2 then
    perform private.asegurar_ot(new.plan_id);
  end if;
  return new;
end $$;

drop trigger if exists trabajos_siguiente_ot on public.trabajos;
create trigger trabajos_siguiente_ot after update of estado on public.trabajos
  for each row execute function private.ot_cerrada_siguiente();

-- Red de seguridad (cron horario): cualquier mantenimiento activo sin OT abierta recibe la suya.
create or replace function private.generar_ots() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select p.id from public.planes_mantenimiento p
    where p.activa
      and not exists (select 1 from public.trabajos t where t.plan_id = p.id and t.activa and t.estado in (0, 1))
  loop
    if private.asegurar_ot(r.id) is not null then n := n + 1; end if;
  end loop;
  return n;
end $$;

revoke all on function private.proximo_estimado(public.planes_mantenimiento), private.asegurar_ot(uuid),
  private.plan_asegura_ot(), private.ot_cerrada_siguiente(), private.generar_ots()
  from public, anon, authenticated;

-- Los mantenimientos que hoy no tienen OT, la reciben ya.
select private.generar_ots();
