-- iPultec (IPT-000): cada app solo ve empresas de su marca. entrar() recibe la marca de la app y crea
-- «Mi empresa» si la cuenta no tiene ninguna de esa marca. Pultec llama sin p_marca (= residencial): igual que antes.
drop function public.entrar(text);
create function public.entrar(p_codigo text default null, p_marca text default 'residencial')
returns table (empresa uuid, creada boolean)
language plpgsql security definer set search_path = '' as $$
declare
  u uuid := (select auth.uid());
  c text := nullif(p_codigo, '');
  i public.invitaciones;
begin
  if p_marca not in ('residencial', 'industrial') then
    raise exception 'Marca no válida' using errcode = '22023';
  end if;
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
  if not exists (
    select 1 from public.miembros m join public.empresas e on e.id = m.empresa_id
    where m.usuario_id = u and e.marca = p_marca
  ) then
    insert into public.empresas (nombre, creada_por, marca) values ('Mi empresa', u, p_marca) returning id into empresa;
    insert into public.miembros (usuario_id, empresa_id, rol) values (u, empresa, 'admin');
    creada := true;
  end if;
  return next;
end
$$;
revoke execute on function public.entrar(text, text) from public, anon;
grant execute on function public.entrar(text, text) to authenticated;
comment on function public.entrar(text, text) is
  'Acepta la invitación (del enlace o guardada en la cuenta) y, si la cuenta no tiene empresa de esa marca (residencial o industrial), le crea una. De una en una por cuenta.';
