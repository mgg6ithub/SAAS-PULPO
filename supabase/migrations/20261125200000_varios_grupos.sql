-- Pultec: un técnico puede estar en varios grupos (antes, como mucho en uno). El área del grupo deja de usarse.
alter table public.trabajadores add column if not exists grupo_ids uuid[] not null default '{}';
update public.trabajadores set grupo_ids = array[grupo_id] where grupo_id is not null and grupo_ids = '{}';
comment on column public.trabajadores.grupo_ids is 'Grupos de técnicos en los que está (puede ser más de uno).';
comment on column public.trabajadores.grupo_id is 'En desuso: ver grupo_ids.';
create index if not exists trabajadores_grupo_ids_idx on public.trabajadores using gin (grupo_ids);

-- Al borrar un grupo, sus técnicos salen de él.
create or replace function private.sacar_de_grupo_borrado() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.trabajadores set grupo_ids = array_remove(grupo_ids, old.id) where old.id = any (grupo_ids);
  return old;
end $$;
revoke all on function private.sacar_de_grupo_borrado() from public, anon, authenticated;
drop trigger if exists grupos_sacar_tecnicos on public.grupos;
create trigger grupos_sacar_tecnicos after delete on public.grupos
  for each row execute function private.sacar_de_grupo_borrado();

-- Técnico del grupo más libre para un día (igual que antes, ahora con varios grupos por técnico).
create or replace function private.tecnico_del_grupo(id_grupo uuid, dia date) returns uuid
language sql stable security definer set search_path = '' as $$
  select w.id
  from public.trabajadores w
  where id_grupo = any (w.grupo_ids) and w.activo
    and not (dia = current_date and w.estado_hoy = 2)
  order by
    (select count(*) from public.trabajo_trabajadores tt join public.trabajos t on t.id = tt.trabajo_id
      where tt.trabajador_id = w.id and t.activa and t.estado in (0, 1) and t.proximo = dia),
    (select count(*) from public.trabajo_trabajadores tt join public.trabajos t on t.id = tt.trabajo_id
      where tt.trabajador_id = w.id and t.activa and t.estado in (0, 1)),
    w.id
  limit 1
$$;
revoke all on function private.tecnico_del_grupo(uuid, date) from public, anon, authenticated;
notify pgrst, 'reload schema';
