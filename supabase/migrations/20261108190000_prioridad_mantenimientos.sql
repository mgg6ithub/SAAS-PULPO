-- Prioridad del preventivo, independiente del tipo de las OT.
alter table public.planes_mantenimiento add column prioridad smallint not null default 0
  check (prioridad between 0 and 2);
update public.planes_mantenimiento set prioridad = tipo_mantenimiento, tipo_mantenimiento = 0;
comment on column public.planes_mantenimiento.prioridad is 'Prioridad del mantenimiento preventivo: 0 normal, 1 alta, 2 crítica.';

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
      0,
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

