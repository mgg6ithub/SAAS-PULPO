-- Pultec: los activos en los que trabaja el técnico (la ventana «¿En qué activos vas a trabajar?») van con su
-- cuenta, no con el dispositivo: entra en otro móvil y ve los mismos.
alter table public.trabajadores add column if not exists activos_elegidos text[] not null default '{}';
comment on column public.trabajadores.activos_elegidos is 'Pultec: activos (máquinas) que el técnico eligió al entrar.';

-- El técnico guarda los suyos (no puede editar su ficha); el administrador, los de cualquiera (vista previa).
create or replace function public.guardar_activos_elegidos(p_trabajador uuid, p_activos text[]) returns void
language plpgsql security definer set search_path = '' as $$
declare emp uuid;
begin
  select w.empresa_id into emp from public.trabajadores w where w.id = p_trabajador;
  if emp is null or not (private.es_admin(emp) or private.mi_trabajador(emp) = p_trabajador) then
    raise exception 'Sin acceso a ese técnico' using errcode = '42501';
  end if;
  update public.trabajadores set activos_elegidos = coalesce(p_activos, '{}') where id = p_trabajador;
end $$;
revoke execute on function public.guardar_activos_elegidos(uuid, text[]) from public, anon;
grant execute on function public.guardar_activos_elegidos(uuid, text[]) to authenticated;
notify pgrst, 'reload schema';
