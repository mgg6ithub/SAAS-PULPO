-- Uso por turnos: patrón semanal por máquina, festivos de la planta y estimación con los dos.
-- Igual que la app (`turnosDe` y `turnosPrevistos` en lib/industrial/planes.dart).
--
-- · activos.patron: turnos de lunes a domingo que se repiten solos ([] = sin patrón). activos.turnos pasa a
--   guardar las excepciones al patrón (un sábado extra; una parada = 0).
-- · festivos: días sin trabajo de la planta. Sin excepción, ninguna máquina trabaja ese día por su patrón.
-- · Sin patrón (como antes): los turnos marcados y, pasado el último, se repite la última semana marcada.
--   Antes, un mantenimiento por horas que no llegaba con los turnos marcados se quedaba sin fecha.

alter table public.activos add column if not exists patron jsonb not null default '[]'::jsonb;

create table if not exists public.festivos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  fecha date not null,
  nombre text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists festivos_empresa_fecha_idx on public.festivos (empresa_id, fecha);

create trigger tocar_updated_at before update on public.festivos
  for each row execute function private.tocar_updated_at();

alter table public.festivos enable row level security;
create policy festivos_select on public.festivos for select to authenticated
  using (private.es_miembro(empresa_id));
create policy festivos_insert on public.festivos for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy festivos_update on public.festivos for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy festivos_delete on public.festivos for delete to authenticated
  using (private.es_admin(empresa_id));
revoke all on public.festivos from anon;
alter publication supabase_realtime add table public.festivos;

-- Turnos de un día: la excepción si la hay; si no, 0 en festivo; si no, el del patrón.
create or replace function private.turnos_de(r public.activos, d date) returns numeric
language plpgsql stable set search_path = '' as $$
begin
  if r.turnos ? to_char(d, 'YYYY-MM-DD') then
    return (r.turnos ->> to_char(d, 'YYYY-MM-DD'))::numeric;
  end if;
  if jsonb_array_length(coalesce(r.patron, '[]'::jsonb)) <> 7 then return 0; end if;
  if exists (select 1 from public.festivos f where f.empresa_id = r.empresa_id and f.fecha = d) then return 0; end if;
  return coalesce((r.patron ->> (extract(isodow from d)::integer - 1))::numeric, 0);
end $$;

-- Turnos previstos para estimar: con patrón, los del día; sin él, se repite la última semana marcada.
create or replace function private.turnos_previstos(r public.activos, d date) returns numeric
language plpgsql stable set search_path = '' as $$
declare
  ultimo date;
begin
  if jsonb_array_length(coalesce(r.patron, '[]'::jsonb)) = 7 then return private.turnos_de(r, d); end if;
  select max(k)::date into ultimo from jsonb_object_keys(coalesce(r.turnos, '{}'::jsonb)) k;
  if ultimo is null then return 0; end if;
  if d > ultimo then d := d - 7 * ceil((d - ultimo) / 7.0)::integer; end if;
  return private.turnos_de(r, d);
end $$;

create or replace function private.horas_hoy(a public.activos) returns numeric
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := private.contador_de(a);
  desde date := coalesce(r.lectura_fecha, current_date);
  turnos numeric := 0;
begin
  if r.uso_planificado then
    select coalesce(sum(private.turnos_de(r, d::date)), 0) into turnos
    from generate_series(desde + 1, current_date, interval '1 day') d;
    return coalesce(r.horas, 0) + turnos * coalesce(r.horas_turno, 8);
  end if;
  return coalesce(r.horas, 0)
    + coalesce(case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end, 0)
      * greatest(0, current_date - desde);
end $$;

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
  r := private.contador_de(a);
  quedan := p.cada_horas - (private.horas_hoy(a) - coalesce(p.ultimo_horas, 0));
  if quedan <= 0 then return current_date; end if;
  if r.uso_planificado then
    for i in 1..400 loop
      d := current_date + i;
      quedan := quedan - private.turnos_previstos(r, d) * coalesce(r.horas_turno, 8);
      if quedan <= 0 then return d; end if;
    end loop;
    return null;
  end if;
  ritmo := case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end;
  if coalesce(ritmo, 0) <= 0 then return null; end if;
  return current_date + ceil(quedan / ritmo)::integer;
end $$;

create or replace function private.dias_hasta_aviso(a public.activos, cuando date) returns integer
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := private.contador_de(a);
  n integer := 0;
begin
  if cuando is null then return null; end if;
  if not r.uso_planificado then return cuando - current_date; end if;
  select count(*) into n
  from generate_series(current_date + 1, cuando, interval '1 day') d
  where private.turnos_previstos(r, d::date) > 0;
  return n;
end $$;

revoke all on function private.turnos_de(public.activos, date) from public, anon, authenticated;
revoke all on function private.turnos_previstos(public.activos, date) from public, anon, authenticated;

-- Al cambiar el uso de una máquina (turnos, patrón, lectura, ritmo) o los festivos: cada mantenimiento por horas
-- lleva su OT pendiente a la nueva fecha estimada y, si no tiene, se crea ya. Así, si el contador llega hoy, la
-- OT queda para hoy en el momento (antes conservaba la fecha con la que se creó). Igual que la app
-- (`reprogramarOts` en lib/industrial/planes.dart).
create or replace function private.reprogramar_ots_activo(id_activo uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  p public.planes_mantenimiento;
  d date;
begin
  for p in
    select * from public.planes_mantenimiento x
    where x.activa and x.proximo is null and x.cada_horas is not null
      and coalesce((private.raiz(x.activo_id)).id, x.activo_id) = id_activo
  loop
    d := private.proximo_estimado(p);
    if d is null then continue; end if;
    update public.trabajos t set proximo = d
    where t.plan_id = p.id and t.activa and t.estado in (0, 1) and t.proximo is distinct from d;
    perform private.asegurar_ot(p.id);
  end loop;
end $$;

create or replace function private.activo_reprograma_ots() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.padre_id is null and (
    new.turnos is distinct from old.turnos or new.patron is distinct from old.patron
    or new.horas is distinct from old.horas or new.lectura_fecha is distinct from old.lectura_fecha
    or new.horas_turno is distinct from old.horas_turno or new.uso_planificado is distinct from old.uso_planificado
    or new.uso_horas is distinct from old.uso_horas or new.uso_semanal is distinct from old.uso_semanal
  ) then
    perform private.reprogramar_ots_activo(new.id);
  end if;
  return new;
end $$;

drop trigger if exists activos_reprograma_ots on public.activos;
create trigger activos_reprograma_ots after update on public.activos
  for each row execute function private.activo_reprograma_ots();

create or replace function private.festivo_reprograma_ots() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  a record;
begin
  for a in
    select id from public.activos
    where empresa_id = coalesce(new.empresa_id, old.empresa_id) and padre_id is null and uso_planificado
  loop
    perform private.reprogramar_ots_activo(a.id);
  end loop;
  return null;
end $$;

drop trigger if exists festivos_reprograma_ots on public.festivos;
create trigger festivos_reprograma_ots after insert or update or delete on public.festivos
  for each row execute function private.festivo_reprograma_ots();

revoke all on function private.reprogramar_ots_activo(uuid), private.activo_reprograma_ots(),
  private.festivo_reprograma_ots() from public, anon, authenticated;
