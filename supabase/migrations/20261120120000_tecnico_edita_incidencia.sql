-- Pultec: quien comunicó una incidencia puede corregirla mientras siga abierta (sin OT ni revisión).
-- Con OT, completada o desestimada ya no se toca: así no cambia lo que la oficina revisó.
create or replace function public.editar_incidencia(
  p_id uuid, p_activo uuid, p_descripcion text, p_gravedad smallint, p_origen uuid, p_fotos text[]
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  i public.incidencias;
  a public.activos;
  texto text := btrim(coalesce(p_descripcion, ''));
  tecnico uuid;
begin
  select * into i from public.incidencias where id = p_id;
  if i.id is null or not private.es_miembro(i.empresa_id)
     or (i.creada_por <> (select auth.uid()) and not private.es_admin(i.empresa_id)) then
    raise exception 'Incidencia no encontrada' using errcode = '42501';
  end if;
  if i.estado <> 0 then
    raise exception 'La incidencia ya está en revisión y no se puede cambiar' using errcode = '42501';
  end if;
  select * into a from public.activos where id = p_activo and empresa_id = i.empresa_id;
  if a.id is null then raise exception 'Activo no encontrado' using errcode = '42501'; end if;
  if p_gravedad not between 0 and 2 then raise exception 'Gravedad no válida' using errcode = '22023'; end if;
  if texto = '' then raise exception 'Falta la descripción' using errcode = '22023'; end if;
  if exists (select 1 from unnest(coalesce(p_fotos, '{}')) f where f not like i.empresa_id || '/incidencias/' || p_id || '/%') then
    raise exception 'Fotos fuera de su carpeta' using errcode = '22023';
  end if;
  tecnico := private.mi_trabajador(i.empresa_id);
  if p_origen is not null and not exists (
    select 1 from public.trabajos t where t.id = p_origen and t.empresa_id = i.empresa_id
    and (private.es_admin(i.empresa_id) or exists (
      select 1 from public.trabajo_trabajadores tw where tw.trabajo_id = t.id and tw.trabajador_id = tecnico))
  ) then raise exception 'Orden no disponible para este técnico' using errcode = '42501'; end if;
  update public.incidencias set
    activo_id = a.id, descripcion = texto, gravedad = p_gravedad,
    origen_trabajo_id = p_origen, fotos = coalesce(p_fotos, '{}'), updated_at = now()
  where id = p_id;
end $$;
revoke execute on function public.editar_incidencia(uuid, uuid, text, smallint, uuid, text[]) from public, anon;
grant execute on function public.editar_incidencia(uuid, uuid, text, smallint, uuid, text[]) to authenticated;
comment on function public.editar_incidencia(uuid, uuid, text, smallint, uuid, text[]) is
  'Pultec: quien la comunicó corrige su incidencia mientras sigue abierta.';
notify pgrst, 'reload schema';
