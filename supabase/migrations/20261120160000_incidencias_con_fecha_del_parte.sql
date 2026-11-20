-- Pultec: la incidencia que deja un parte lleva la fecha del parte (partes subidos más tarde, sin conexión, o
-- historial importado), no la de hoy.
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
      (empresa_id, activo_id, descripcion, gravedad, estado, fotos, creada_por, tecnico_id, origen_trabajo_id, created_at)
    values (t.empresa_id, t.activo_id,
      concat_ws(': ',
        case new.resultado when 1 then 'Con incidencias en «' || t.nombre || '»' else 'No se pudo hacer «' || t.nombre || '»' end,
        nullif(btrim(new.notas), '')),
      1, 0, new.fotos, quien, tecnico, t.id, new.created_at);
  end if;
  return new;
end $$;

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
      (empresa_id, activo_id, descripcion, gravedad, estado, creada_por, tecnico_id, origen_trabajo_id, created_at)
    values (t.empresa_id, t.activo_id,
      p.medicion_nombre || ' fuera de límites: ' || new.valor::text || coalesce(nullif(' ' || p.medicion_unidad, ' '), '')
        || ' (admitido de ' || coalesce(p.medicion_min::text, '…') || ' a ' || coalesce(p.medicion_max::text, '…') || ')',
      1, 0, quien,
      case when (select auth.uid()) is null or private.es_admin(t.empresa_id) then new.trabajador_id
           else private.mi_trabajador(t.empresa_id) end,
      t.id, new.created_at);
  end if;
  return new;
end $$;
