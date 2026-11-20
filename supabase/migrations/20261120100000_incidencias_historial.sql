-- Pultec: incidencias con historial completo (comentarios del 18/11/2026).
--  · estado: 0 abierta, 1 con OT, 2 completada (su OT se cerró), 3 desestimada (cerrada sin hacer nada);
--  · cerrada_el: cuándo se completó o se desestimó;
--  · plan_id: mantenimiento vinculado; al completarse la incidencia se reinicia su contador y su OT se re-estima;
--  · al cerrar la OT que la resuelve, la incidencia pasa sola a completada (y vuelve a «con OT» si se reabre);
--  · un parte con incidencia o sin hacer deja su incidencia abierta: ya nada se pierde al darlo por visto;
--  · el técnico ve la incidencia (y sus fotos) de la OT que tiene asignada;
--  · OT con repuestos y procedimiento propios (los de su mantenimiento, ya no mezclados en las notas).

-- ── Estados y columnas nuevas ───────────────────────────────────────────────
alter table public.incidencias drop constraint if exists incidencias_estado_check;
alter table public.incidencias add constraint incidencias_estado_check check (estado between 0 and 3);
alter table public.incidencias
  add column if not exists plan_id uuid references public.planes_mantenimiento (id) on delete set null,
  add column if not exists cerrada_el timestamptz;
create index if not exists incidencias_plan_id_idx on public.incidencias (plan_id);
comment on column public.incidencias.estado is '0 abierta, 1 con OT, 2 completada (OT cerrada), 3 desestimada.';
comment on column public.incidencias.plan_id is 'Mantenimiento vinculado: al completarse la incidencia se reinicia su contador.';
comment on column public.incidencias.cerrada_el is 'Cuándo se completó o se desestimó (null mientras sigue abierta).';

alter table public.trabajos
  add column if not exists repuestos text not null default '',
  add column if not exists procedimiento text not null default '';
comment on column public.trabajos.repuestos is 'OT industrial: repuestos necesarios (de su mantenimiento o puestos a mano).';
comment on column public.trabajos.procedimiento is 'OT industrial: cómo se hace (de su mantenimiento o puesto a mano).';

-- ── Al cambiar una incidencia: fecha de cierre y reinicio del mantenimiento vinculado ──
create or replace function private.incidencia_al_cambiar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  p public.planes_mantenimiento;
  a public.activos;
begin
  -- Sin OT (borrada) ya no puede estar «con OT».
  if new.estado = 1 and new.trabajo_id is null then new.estado := 0; end if;
  if new.estado >= 2 then
    if tg_op = 'INSERT' or old.estado < 2 then new.cerrada_el := coalesce(new.cerrada_el, now()); end if;
  else
    new.cerrada_el := null;
  end if;
  if new.estado = 2 and new.plan_id is not null and (tg_op = 'INSERT' or old.estado is distinct from 2) then
    select * into p from public.planes_mantenimiento where id = new.plan_id and empresa_id = new.empresa_id;
    if p.id is not null then
      select * into a from public.activos where id = p.activo_id;
      update public.planes_mantenimiento set
        ultimo = current_date,
        ultimo_horas = private.horas_hoy(a),
        proximo = case when p.cada_dias is not null then current_date + p.cada_dias
                       when p.cada_horas is not null then null else p.proximo end
      where id = p.id
      returning * into p;
      -- Su OT pendiente pasa a la nueva fecha estimada.
      update public.trabajos set proximo = coalesce(private.proximo_estimado(p), proximo)
      where plan_id = p.id and activa and estado in (0, 1);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists incidencias_al_cambiar on public.incidencias;
create trigger incidencias_al_cambiar before insert or update on public.incidencias
  for each row execute function private.incidencia_al_cambiar();

-- ── La OT que resuelve una incidencia la completa al cerrarse ───────────────
create or replace function private.ot_cerrada_incidencias() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 2 and old.estado is distinct from 2 then
    update public.incidencias set estado = 2 where trabajo_id = new.id and estado in (0, 1);
  elsif old.estado = 2 and new.estado <> 2 then
    update public.incidencias set estado = 1 where trabajo_id = new.id and estado = 2;
  end if;
  return new;
end $$;

drop trigger if exists trabajos_cierra_incidencias on public.trabajos;
create trigger trabajos_cierra_incidencias after update of estado on public.trabajos
  for each row execute function private.ot_cerrada_incidencias();

-- Datos de antes: «cerrada» sin OT = desestimada; «con OT» con la OT ya cerrada = completada.
update public.incidencias set estado = 3 where estado = 2 and trabajo_id is null;
update public.incidencias i set estado = 2
from public.trabajos t where t.id = i.trabajo_id and i.estado = 1 and t.estado = 2;

-- ── Un parte con incidencia o sin hacer deja su incidencia abierta ──────────
create or replace function private.resultado_en_ot() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  t public.trabajos;
  quien uuid := coalesce(new.creado_por, (select auth.uid()));
  tecnico uuid;
begin
  update public.trabajos set resultado = new.resultado, resultado_resuelto = false
  where id = new.trabajo_id and empresa_id = new.empresa_id
  returning * into t;
  if new.resultado > 0 and t.activo_id is not null and quien is not null and not exists (
    select 1 from public.incidencias i where i.origen_trabajo_id = t.id and i.estado in (0, 1)
  ) then
    -- Un técnico solo puede comunicar en su nombre (lo valida `validar_referencias_incidencia`).
    tecnico := case when (select auth.uid()) is null or private.es_admin(t.empresa_id) then new.trabajador_id
                    else private.mi_trabajador(t.empresa_id) end;
    insert into public.incidencias
      (empresa_id, activo_id, descripcion, gravedad, estado, fotos, creada_por, tecnico_id, origen_trabajo_id)
    values (t.empresa_id, t.activo_id,
      concat_ws(': ',
        case new.resultado when 1 then 'Con incidencias en «' || t.nombre || '»' else 'No se pudo hacer «' || t.nombre || '»' end,
        nullif(btrim(new.notas), '')),
      1, 0, new.fotos, quien, tecnico, t.id);
  end if;
  return new;
end $$;

-- Los partes con incidencia que siguen sin solucionar pasan al historial de incidencias.
insert into public.incidencias
  (empresa_id, activo_id, descripcion, gravedad, estado, fotos, creada_por, tecnico_id, origen_trabajo_id, created_at)
select t.empresa_id, t.activo_id,
  concat_ws(': ',
    case t.resultado when 1 then 'Con incidencias en «' || t.nombre || '»' else 'No se pudo hacer «' || t.nombre || '»' end,
    nullif(btrim(i.notas), '')),
  1, 0, i.fotos, i.creado_por, i.trabajador_id, t.id, i.created_at
from public.trabajos t
join lateral (
  select x.* from public.informes x where x.trabajo_id = t.id order by x.created_at desc limit 1
) i on true
where t.resultado > 0 and not t.resultado_resuelto and t.activo_id is not null and i.creado_por is not null
  and not exists (select 1 from public.incidencias y where y.origen_trabajo_id = t.id);

-- ── El técnico ve la incidencia de la OT que tiene asignada (y sus fotos) ───
drop policy if exists incidencias_select on public.incidencias;
create policy incidencias_select on public.incidencias for select to authenticated
  using (private.es_admin(empresa_id) or (private.es_miembro(empresa_id) and (
    creada_por = (select auth.uid())
    or exists (select 1 from public.trabajo_trabajadores tw
               where tw.trabajo_id = incidencias.trabajo_id
                 and tw.trabajador_id = private.mi_trabajador(incidencias.empresa_id)))));

-- Las fotos de una incidencia se ven si se ve la incidencia (la consulta ya pasa por su RLS).
drop policy if exists fotos_incidencias_visibles on storage.objects;
create policy fotos_incidencias_visibles on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[2] = 'incidencias'
         and exists (select 1 from public.incidencias i where i.id::text = (storage.foldername(name))[3]));

-- ── OT automáticas: repuestos y procedimiento en sus columnas ───────────────
create or replace function private.asegurar_ot(id_plan uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  r public.planes_mantenimiento;
  emp uuid;
  nueva uuid;
  dia date;
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
  dia := private.proximo_estimado(r);
  insert into public.trabajos (
    id, empresa_id, activo_id, plan_id, grupo_id, nombre, plantilla, proximo, periodicidad, criticidad,
    duracion_min, estado, activa, competencias, tipo_mantenimiento, notas, repuestos, procedimiento
  ) values (
    nueva, emp, r.activo_id, r.id, r.grupo_id,
    r.nombre || case when r.subcontratado then ' (subcontratado)' else '' end,
    false, dia, 5, 3, r.duracion_min, 0, true,
    case when r.categoria <> '' and not r.subcontratado then array[r.categoria] else array[]::text[] end,
    0,
    concat_ws(e'\n\n',
      nullif(case when r.subcontratado then 'Lo hace una empresa externa: ' || nullif(r.empresa_externa, '') end, ''),
      nullif('Preparar: ' || nullif(r.preparar, ''), '')),
    r.repuestos, r.procedimiento
  );
  if r.subcontratado then return nueva; end if;
  if r.trabajador_id is not null then
    select w.id into tecnico from public.trabajadores w where w.id = r.trabajador_id and w.activo;
  elsif r.grupo_id is not null then
    tecnico := private.tecnico_del_grupo(r.grupo_id, coalesce(dia, current_date));
  elsif r.categoria <> '' then
    select min(w.id::text)::uuid into tecnico
    from public.trabajadores w
    where w.empresa_id = emp and w.activo and r.categoria = any (w.competencias)
    having count(*) = 1;
  end if;
  if tecnico is not null then
    insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (nueva, tecnico, emp);
  end if;
  return nueva;
end $$;

revoke all on function private.incidencia_al_cambiar(), private.ot_cerrada_incidencias(), private.resultado_en_ot(),
  private.asegurar_ot(uuid) from public, anon, authenticated;
notify pgrst, 'reload schema';
