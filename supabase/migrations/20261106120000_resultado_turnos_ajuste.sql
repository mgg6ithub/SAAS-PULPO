-- Pultec, mejoras de los vídeos 3-5:
--  · resultado de cada OT (bien, con incidencia, no se pudo hacer) y si la incidencia ya se ha solucionado;
--  · ajuste de empresa para que las OT por horas se creen solas (activado por defecto);
--  · uso de las máquinas planificado a mano por turnos (calendario del mes);
--  · los componentes cuentan las horas de su activo principal.

alter table public.trabajos
  add column if not exists resultado smallint check (resultado between 0 and 2),
  add column if not exists resultado_resuelto boolean not null default false;

alter table public.empresas
  add column if not exists ots_automaticas boolean not null default true;

alter table public.activos
  add column if not exists uso_planificado boolean not null default false,
  add column if not exists horas_turno numeric not null default 8,
  add column if not exists turnos jsonb not null default '{}'::jsonb;

-- El parte del técnico deja su resultado en la OT (también los que se suben más tarde, sin conexión).
create or replace function private.resultado_en_ot() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.trabajos set resultado = new.resultado, resultado_resuelto = false
  where id = new.trabajo_id and empresa_id = new.empresa_id;
  return new;
end $$;

drop trigger if exists informes_resultado_en_ot on public.informes;
create trigger informes_resultado_en_ot after insert on public.informes
  for each row execute function private.resultado_en_ot();

-- Activo principal (sin padre) del que cuelga un activo o componente.
create or replace function private.raiz(id_activo uuid) returns public.activos
language sql stable set search_path = '' as $$
  with recursive arriba as (
    select a.*, 0 as nivel from public.activos a where a.id = id_activo
    union all
    select p.*, arriba.nivel + 1 from public.activos p join arriba on p.id = arriba.padre_id
  )
  select x.* from public.activos x where x.id = (select id from arriba order by nivel desc limit 1)
$$;

-- Horas de hoy de un activo: las de su activo principal. Uso planificado: la lectura más los turnos
-- marcados desde entonces; si no, la lectura más el ritmo de uso.
create or replace function private.horas_hoy(a public.activos) returns numeric
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := coalesce(private.raiz(a.id), a);
  desde date := coalesce(r.lectura_fecha, current_date);
  turnos numeric := 0;
begin
  if r.uso_planificado then
    select coalesce(sum((t.value)::numeric), 0) into turnos
    from jsonb_each_text(r.turnos) t
    where t.key::date > desde and t.key::date <= current_date;
    return coalesce(r.horas, 0) + turnos * coalesce(r.horas_turno, 8);
  end if;
  return coalesce(r.horas, 0)
    + coalesce(case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end, 0)
      * greatest(0, current_date - desde);
end $$;

-- Generar OT: solo las de mantenimientos por horas que ya han llegado, y solo si la empresa lo tiene activado.
create or replace function private.generar_ots() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  nueva uuid;
  tecnico uuid;
  n integer := 0;
begin
  for r in
    select p.*, a.empresa_id as emp
    from public.planes_mantenimiento p
    join public.activos a on a.id = p.activo_id
    join public.empresas e on e.id = a.empresa_id
    where p.activa
      and e.ots_automaticas
      and p.cada_horas is not null
      and private.horas_hoy(a) - coalesce(p.ultimo_horas, 0) >= p.cada_horas
      and not exists (
        select 1 from public.trabajos t
        where t.plan_id = p.id and t.activa and t.estado in (0, 1)
      )
  loop
    nueva := gen_random_uuid();
    insert into public.trabajos (
      id, empresa_id, activo_id, plan_id, nombre, plantilla, proximo, periodicidad, criticidad,
      duracion_min, estado, activa, competencias, tipo_mantenimiento, notas
    ) values (
      nueva, r.emp, r.activo_id, r.id,
      r.nombre || case when r.subcontratado then ' (subcontratado)' else '' end,
      false, current_date, 5, 3, r.duracion_min, 0, true,
      case when r.categoria <> '' and not r.subcontratado then array[r.categoria] else array[]::text[] end,
      r.tipo_mantenimiento,
      concat_ws(e'\n\n',
        nullif(case when r.subcontratado then 'Lo hace una empresa externa: ' || nullif(r.empresa_externa, '') end, ''),
        nullif(r.procedimiento, ''),
        nullif('Repuestos: ' || nullif(r.repuestos, ''), ''),
        nullif('Preparar: ' || nullif(r.preparar, ''), ''))
    );
    if not r.subcontratado and r.categoria <> '' then
      select min(w.id::text)::uuid into tecnico
      from public.trabajadores w
      where w.empresa_id = r.emp and w.activo and r.categoria = any (w.competencias)
      having count(*) = 1;
      if tecnico is not null then
        insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (nueva, tecnico, r.emp);
      end if;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function private.generar_ots(), private.resultado_en_ot(), private.raiz(uuid) from public, anon, authenticated;

select cron.unschedule('ipultec-mantenimientos');
select cron.schedule('ipultec-mantenimientos', '7 * * * *', $cron$
  select private.generar_ots();
  select private.encolar_avisos_planes();
$cron$);
