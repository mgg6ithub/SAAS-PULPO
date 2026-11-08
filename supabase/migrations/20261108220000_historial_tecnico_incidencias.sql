alter table public.incidencias
  add column tecnico_id uuid,
  add column origen_trabajo_id uuid,
  add constraint incidencias_tecnico_id_fkey foreign key (tecnico_id, empresa_id)
    references public.trabajadores(id, empresa_id) on delete set null (tecnico_id),
  add constraint incidencias_origen_trabajo_id_fkey foreign key (origen_trabajo_id, empresa_id)
    references public.trabajos(id, empresa_id) on delete set null (origen_trabajo_id);
create index incidencias_tecnico_id_idx on public.incidencias(tecnico_id);
create index incidencias_origen_trabajo_id_idx on public.incidencias(origen_trabajo_id);
comment on column public.incidencias.tecnico_id is 'Técnico que comunica el aviso; creada_por conserva la cuenta autenticada.';
comment on column public.incidencias.origen_trabajo_id is 'Orden desde la que se comunica; trabajo_id es la orden creada para resolver la incidencia.';

update public.incidencias i set tecnico_id = m.trabajador_id
from public.miembros m where m.usuario_id = i.creada_por and m.empresa_id = i.empresa_id;

create or replace function private.validar_referencias_incidencia() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.tecnico_id is not null and not exists (
    select 1 from public.trabajadores w where w.id = new.tecnico_id and w.empresa_id = new.empresa_id
  ) then raise exception 'Técnico de otra empresa' using errcode = '42501'; end if;
  if new.origen_trabajo_id is not null and not exists (
    select 1 from public.trabajos t where t.id = new.origen_trabajo_id and t.empresa_id = new.empresa_id
  ) then raise exception 'Orden de otra empresa' using errcode = '42501'; end if;
  if (select auth.uid()) is not null and not private.es_admin(new.empresa_id) and new.tecnico_id is not null and not exists (
    select 1 from public.miembros m where m.empresa_id = new.empresa_id
    and m.usuario_id = (select auth.uid()) and m.trabajador_id = new.tecnico_id
  ) then raise exception 'No puedes comunicar por otro técnico' using errcode = '42501'; end if;
  return new;
end
$$;
create trigger validar_referencias_incidencia before insert or update of tecnico_id, origen_trabajo_id, empresa_id
on public.incidencias for each row execute function private.validar_referencias_incidencia();
comment on function private.validar_referencias_incidencia() is 'Valida empresa y autoría de las referencias del historial de incidencias.';

-- Conserva el RPC anterior para clientes abiertos, con una variante que admite origen y técnico.
create function public.crear_incidencia(
  p_id uuid, p_activo uuid, p_descripcion text, p_gravedad smallint, p_categoria text,
  p_fotos text[], p_tecnico uuid, p_origen uuid
) returns uuid language plpgsql security definer set search_path = '' as $$
declare e uuid; tecnico uuid; aviso uuid;
begin
  select empresa_id into e from public.activos where id = p_activo;
  if e is null or not private.es_miembro(e) then
    raise exception 'Activo no encontrado' using errcode = '42501';
  end if;
  if private.es_admin(e) then tecnico := p_tecnico;
  else
    select m.trabajador_id into tecnico from public.miembros m
    where m.empresa_id = e and m.usuario_id = (select auth.uid());
    if p_tecnico is distinct from tecnico then
      raise exception 'Técnico no válido' using errcode = '42501';
    end if;
  end if;
  if p_origen is not null and not exists (
    select 1 from public.trabajos t where t.id = p_origen and t.empresa_id = e
    and (private.es_admin(e) or exists (
      select 1 from public.trabajo_trabajadores tw where tw.trabajo_id = t.id and tw.trabajador_id = tecnico
    ))
  ) then raise exception 'Orden no disponible para este técnico' using errcode = '42501'; end if;
  aviso := public.crear_incidencia(p_id, p_activo, p_descripcion, p_gravedad, p_categoria, p_fotos);
  update public.incidencias set tecnico_id = tecnico, origen_trabajo_id = p_origen where id = aviso;
  return aviso;
end
$$;
revoke execute on function public.crear_incidencia(uuid,uuid,text,smallint,text,text[],uuid,uuid) from public, anon;
grant execute on function public.crear_incidencia(uuid,uuid,text,smallint,text,text[],uuid,uuid) to authenticated;
comment on function public.crear_incidencia(uuid,uuid,text,smallint,text,text[],uuid,uuid) is 'Comunica un aviso pendiente de revisión, conservando técnico, orden de origen y fecha.';
notify pgrst, 'reload schema';
