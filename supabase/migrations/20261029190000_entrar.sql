-- Entrar en la app en un solo paso y sin carreras (BUG del enlace de trabajador que entraba como administrador).
-- Antes la app aceptaba la invitación y, si no veía ninguna empresa, creaba «Mi empresa». Con dos pestañas a la
-- vez (la del enlace y la de confirmar el correo comparten sesión), una aceptaba y la otra, sin el código, creaba
-- una empresa propia: la cuenta quedaba de administrador. Ahora todo pasa aquí, de una en una por cuenta, y el
-- código también se lee de la cuenta (la app lo guarda al crearla), así vale desde cualquier pestaña.
create function public.entrar(p_codigo text default null)
returns table (empresa uuid, creada boolean)
language plpgsql security definer set search_path = '' as $$
declare
  u uuid := (select auth.uid());
  c text := nullif(p_codigo, '');
  i public.invitaciones;
begin
  if u is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '28000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text, 0));
  if c is null then
    select nullif(raw_user_meta_data ->> 'invitacion', '') into c from auth.users where id = u;
  end if;
  creada := false;
  if c is not null then
    select * into i from public.invitaciones where codigo = c for update;
    if found and i.usada_por = u then
      -- Ya la aceptó esta cuenta (otra pestaña): se entra en esa empresa si sigue siendo miembro.
      select m.empresa_id into empresa from public.miembros m where m.usuario_id = u and m.empresa_id = i.empresa_id;
    elsif found and i.usada_por is null and i.caduca_en >= now() then
      insert into public.miembros (usuario_id, empresa_id, rol, trabajador_id)
      values (u, i.empresa_id, i.rol, i.trabajador_id)
      on conflict (usuario_id, empresa_id) do update
        set rol = case when public.miembros.rol = 'admin' then 'admin' else excluded.rol end,
            trabajador_id = coalesce(excluded.trabajador_id, public.miembros.trabajador_id);
      update public.invitaciones set usada_por = u, usada_en = now() where id = i.id;
      empresa := i.empresa_id;
    elsif p_codigo is not null then
      raise exception 'Invitación no válida o caducada' using errcode = 'P0001';
    end if;
  end if;
  if not exists (select 1 from public.miembros m where m.usuario_id = u) then
    insert into public.empresas (nombre, creada_por) values ('Mi empresa', u) returning id into empresa;
    insert into public.miembros (usuario_id, empresa_id, rol) values (u, empresa, 'admin');
    creada := true;
  end if;
  return next;
end
$$;
revoke execute on function public.entrar(text) from public, anon;
grant execute on function public.entrar(text) to authenticated;
comment on function public.entrar(text) is
  'Acepta la invitación (del enlace o guardada en la cuenta) y, si la cuenta no tiene empresa, le crea una. De una en una por cuenta.';
