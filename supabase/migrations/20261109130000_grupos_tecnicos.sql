-- Pultec: grupos de técnicos (p. ej. «Hidráulica A»). Un técnico está en un grupo como mucho.
-- Una OT o un mantenimiento se puede asignar a un grupo: la OT se reparte sola al técnico del grupo más libre.

create table public.grupos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nombre text not null check (btrim(nombre) <> ''),
  area text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Dos grupos no pueden llamarse igual en la misma empresa.
create unique index grupos_empresa_nombre_idx on public.grupos (empresa_id, lower(btrim(nombre)));

create trigger tocar_updated_at before update on public.grupos
  for each row execute function private.tocar_updated_at();

alter table public.grupos enable row level security;
create policy grupos_select on public.grupos for select to authenticated
  using (private.es_miembro(empresa_id));
create policy grupos_insert on public.grupos for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy grupos_update on public.grupos for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy grupos_delete on public.grupos for delete to authenticated
  using (private.es_admin(empresa_id));
revoke all on public.grupos from anon;
alter publication supabase_realtime add table public.grupos;

alter table public.trabajadores add column if not exists grupo_id uuid references public.grupos (id) on delete set null;
alter table public.trabajos add column if not exists grupo_id uuid references public.grupos (id) on delete set null;
alter table public.planes_mantenimiento
  add column if not exists grupo_id uuid references public.grupos (id) on delete set null,
  add column if not exists trabajador_id uuid references public.trabajadores (id) on delete set null;
create index if not exists trabajadores_grupo_id_idx on public.trabajadores (grupo_id);
create index if not exists trabajos_grupo_id_idx on public.trabajos (grupo_id);
create index if not exists planes_mantenimiento_grupo_id_idx on public.planes_mantenimiento (grupo_id);
create index if not exists planes_mantenimiento_trabajador_id_idx on public.planes_mantenimiento (trabajador_id);

-- Técnico del grupo más libre para un día: el que menos OT abiertas tiene ese día y, a igualdad, en total.
-- Los ausentes hoy no cuentan si la OT es para hoy.
create or replace function private.tecnico_del_grupo(id_grupo uuid, dia date) returns uuid
language sql stable security definer set search_path = '' as $$
  select w.id
  from public.trabajadores w
  where w.grupo_id = id_grupo and w.activo
    and not (dia = current_date and w.estado_hoy = 2)
  order by
    (select count(*) from public.trabajo_trabajadores tt join public.trabajos t on t.id = tt.trabajo_id
      where tt.trabajador_id = w.id and t.activa and t.estado in (0, 1) and t.proximo = dia),
    (select count(*) from public.trabajo_trabajadores tt join public.trabajos t on t.id = tt.trabajo_id
      where tt.trabajador_id = w.id and t.activa and t.estado in (0, 1)),
    w.id
  limit 1
$$;

-- La OT de un mantenimiento: a su técnico, o repartida en su grupo, o (como antes) al único de su categoría.
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
    duracion_min, estado, activa, competencias, tipo_mantenimiento, notas
  ) values (
    nueva, emp, r.activo_id, r.id, r.grupo_id,
    r.nombre || case when r.subcontratado then ' (subcontratado)' else '' end,
    false, dia, 5, 3, r.duracion_min, 0, true,
    case when r.categoria <> '' and not r.subcontratado then array[r.categoria] else array[]::text[] end,
    0,
    concat_ws(e'\n\n',
      nullif(case when r.subcontratado then 'Lo hace una empresa externa: ' || nullif(r.empresa_externa, '') end, ''),
      nullif(r.procedimiento, ''),
      nullif('Repuestos: ' || nullif(r.repuestos, ''), ''),
      nullif('Preparar: ' || nullif(r.preparar, ''), ''))
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

revoke all on function private.tecnico_del_grupo(uuid, date), private.asegurar_ot(uuid) from public, anon, authenticated;
