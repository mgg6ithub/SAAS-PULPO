-- Pultec DEV-052: checklists de pasos.
--  · el activo y el mantenimiento guardan sus pasos (plantilla reutilizable);
--  · cada OT guarda su propia copia con lo hecho (paso, hecho, cuándo, quién, nota): una OT por ocurrencia,
--    así que no hace falta otra tabla ni copiarla en el parte;
--  · el técnico la marca en vivo con `marcar_checklist` (solo si la OT es suya; la oficina, siempre).
alter table public.activos add column if not exists checklist text[] not null default '{}';
alter table public.planes_mantenimiento add column if not exists checklist text[] not null default '{}';
alter table public.trabajos add column if not exists checklist jsonb not null default '[]';
comment on column public.activos.checklist is 'Pasos de la checklist del activo (se usa si su mantenimiento no tiene).';
comment on column public.planes_mantenimiento.checklist is 'Pasos de la checklist de este mantenimiento.';
comment on column public.trabajos.checklist is
  'Copia de la checklist en esta OT: [{paso, hecho, cuando, por, nota}]. Solo la escribe marcar_checklist.';

create or replace function private.marcar_checklist(p_trabajo uuid, p_checklist jsonb) returns void
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
  if jsonb_typeof(p_checklist) <> 'array' or jsonb_array_length(p_checklist) > 100
     or octet_length(p_checklist::text) > 50000 then
    raise exception 'Checklist no válida' using errcode = '22023';
  end if;
  update public.trabajos set checklist = p_checklist where id = t.id;
end $$;
revoke execute on function private.marcar_checklist(uuid, jsonb) from public, anon;
grant execute on function private.marcar_checklist(uuid, jsonb) to authenticated;
create or replace function public.marcar_checklist(p_trabajo uuid, p_checklist jsonb) returns void
language sql security invoker set search_path = '' as $$ select private.marcar_checklist(p_trabajo, p_checklist) $$;
revoke execute on function public.marcar_checklist(uuid, jsonb) from public, anon;
grant execute on function public.marcar_checklist(uuid, jsonb) to authenticated;
comment on function public.marcar_checklist(uuid, jsonb) is 'Pultec: guarda la checklist de una OT (técnico asignado u oficina).';
notify pgrst, 'reload schema';
