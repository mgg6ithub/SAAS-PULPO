-- Pultec: verificaciones con dato numérico (estadísticas del 18/11/2026).
--  · el mantenimiento puede pedir una medición: nombre, unidad y límites opcionales;
--  · el técnico apunta el valor en su parte (`informes.valor`);
--  · fuera de límites, la base abre una incidencia sola para que la oficina lo revise.
alter table public.planes_mantenimiento
  add column if not exists medicion_nombre text not null default '',
  add column if not exists medicion_unidad text not null default '',
  add column if not exists medicion_min numeric,
  add column if not exists medicion_max numeric;
comment on column public.planes_mantenimiento.medicion_nombre is 'Verificación con dato: qué se mide (vacío = no pide medición).';
comment on column public.planes_mantenimiento.medicion_min is 'Límite inferior admitido (null = sin límite).';
comment on column public.planes_mantenimiento.medicion_max is 'Límite superior admitido (null = sin límite).';

alter table public.informes add column if not exists valor numeric;
comment on column public.informes.valor is 'Valor medido en el parte, si su mantenimiento pide medición.';

create or replace function private.medicion_fuera_de_limites() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  t public.trabajos;
  p public.planes_mantenimiento;
  quien uuid := coalesce(new.creado_por, (select auth.uid()));
begin
  if new.valor is null then return new; end if;
  select * into t from public.trabajos where id = new.trabajo_id and empresa_id = new.empresa_id;
  if t.plan_id is null or t.activo_id is null or quien is null then return new; end if;
  select * into p from public.planes_mantenimiento where id = t.plan_id;
  if p.id is null or p.medicion_nombre = '' then return new; end if;
  if (p.medicion_min is not null and new.valor < p.medicion_min)
     or (p.medicion_max is not null and new.valor > p.medicion_max) then
    insert into public.incidencias
      (empresa_id, activo_id, descripcion, gravedad, estado, creada_por, tecnico_id, origen_trabajo_id)
    values (t.empresa_id, t.activo_id,
      p.medicion_nombre || ' fuera de límites: ' || new.valor::text || coalesce(nullif(' ' || p.medicion_unidad, ' '), '')
        || ' (admitido de ' || coalesce(p.medicion_min::text, '…') || ' a ' || coalesce(p.medicion_max::text, '…') || ')',
      1, 0, quien,
      case when (select auth.uid()) is null or private.es_admin(t.empresa_id) then new.trabajador_id
           else private.mi_trabajador(t.empresa_id) end,
      t.id);
  end if;
  return new;
end $$;

drop trigger if exists informes_medicion_fuera on public.informes;
create trigger informes_medicion_fuera after insert on public.informes
  for each row execute function private.medicion_fuera_de_limites();
revoke all on function private.medicion_fuera_de_limites() from public, anon, authenticated;
notify pgrst, 'reload schema';
