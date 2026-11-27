-- OT pausada: el técnico la pausa (comer, esperar una pieza) o se pausa sola al avisar de una incidencia desde ella.
-- No es un estado nuevo (estado sigue en 1, «en curso», para no tocar las funciones que usan estado in (0, 1)):
-- pausada_desde no nulo = pausada. El tiempo pausado no cuenta y queda en el informe.
alter table public.trabajos
  add column if not exists iniciada_en timestamptz,
  add column if not exists pausada_desde timestamptz,
  add column if not exists segundos_pausa integer not null default 0,
  add column if not exists pausas smallint not null default 0;

comment on column public.trabajos.iniciada_en is 'Cuándo pulsó el técnico «Empezar OT» por primera vez.';
comment on column public.trabajos.pausada_desde is 'Desde cuándo está pausada (null = no está pausada).';
comment on column public.trabajos.segundos_pausa is 'Tiempo total que ha estado pausada (ya reanudada).';
comment on column public.trabajos.pausas is 'Cuántas veces se ha pausado.';

-- Empezar OT apunta además cuándo empezó (la primera vez).
create or replace function private.tomar_ot(p_trabajo uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.trabajos; w uuid;
begin
  select * into t from public.trabajos where id = p_trabajo for update;
  if not found then
    raise exception 'OT no encontrada' using errcode = 'P0001';
  end if;
  w := private.mi_trabajador(t.empresa_id);
  if w is null then
    raise exception 'Solo un técnico puede tomar una OT' using errcode = '42501';
  end if;
  if (select e.marca from public.empresas e where e.id = t.empresa_id) <> 'industrial'
     or not t.activa or t.plantilla or t.tipo_mantenimiento is null or t.estado not in (0, 1) then
    raise exception 'Esta OT ya no está pendiente' using errcode = '42501';
  end if;
  if not exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = t.id and tt.trabajador_id = w) then
    if not private.ot_libre_de_mi_categoria(t.id) then
      raise exception 'Esta OT ya no está libre o no es de tu categoría' using errcode = '42501';
    end if;
    insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (t.id, w, t.empresa_id);
  end if;
  update public.trabajos set estado = 1, iniciada_en = coalesce(iniciada_en, now()) where id = t.id;
end
$$;

-- Pausar (p_pausar) o reanudar una OT en curso: el técnico asignado o la oficina.
create or replace function private.pausar_ot(p_trabajo uuid, p_pausar boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.trabajos;
begin
  select * into t from public.trabajos where id = p_trabajo for update;
  if not found or not private.es_miembro(t.empresa_id) then
    raise exception 'OT no encontrada' using errcode = 'P0001';
  end if;
  if not private.es_admin(t.empresa_id) and not exists (
    select 1 from public.trabajo_trabajadores tt
    where tt.trabajo_id = t.id and tt.trabajador_id = private.mi_trabajador(t.empresa_id)) then
    raise exception 'Esta OT no es tuya' using errcode = '42501';
  end if;
  if t.estado <> 1 then
    raise exception 'Solo se pausa una OT en curso' using errcode = '42501';
  end if;
  if p_pausar and t.pausada_desde is null then
    update public.trabajos set pausada_desde = now(), pausas = pausas + 1 where id = t.id;
  elsif not p_pausar and t.pausada_desde is not null then
    update public.trabajos
      set segundos_pausa = segundos_pausa + greatest(0, extract(epoch from now() - t.pausada_desde)::integer),
          pausada_desde = null
      where id = t.id;
  end if;
end
$$;
revoke execute on function private.pausar_ot(uuid, boolean) from public, anon;
grant execute on function private.pausar_ot(uuid, boolean) to authenticated;

create or replace function public.pausar_ot(p_trabajo uuid, p_pausar boolean) returns void
language sql security invoker set search_path = '' as $$ select private.pausar_ot(p_trabajo, p_pausar) $$;
revoke execute on function public.pausar_ot(uuid, boolean) from public, anon;
grant execute on function public.pausar_ot(uuid, boolean) to authenticated;
comment on function public.pausar_ot(uuid, boolean) is 'Pultec: pausa o reanuda una OT en curso (el tiempo pausado no cuenta).';
