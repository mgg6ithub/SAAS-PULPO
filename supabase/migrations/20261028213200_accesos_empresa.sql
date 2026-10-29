-- DEV-020 · Gestión de accesos: el correo de cada cuenta en su perfil (para la lista de accesos) y que una
-- empresa nunca se quede sin administrador.

-- ── Correo en el perfil, copiado de Auth ────────────────────────────────────
alter table public.perfiles add column correo text not null default '';
comment on column public.perfiles.correo is 'Copia del correo de la cuenta (lo mantiene el trigger copiar_correo de auth.users); la app no puede leer auth.users.';

-- El usuario solo cambia su nombre y su foto; el correo lo pone el trigger.
revoke insert, update on public.perfiles from authenticated;
grant insert (usuario_id, nombre, foto), update (nombre, foto) on public.perfiles to authenticated;

create function private.copiar_correo() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.perfiles (usuario_id, correo) values (new.id, coalesce(new.email, ''))
  on conflict (usuario_id) do update set correo = excluded.correo;
  return new;
end
$$;
revoke execute on function private.copiar_correo() from public, anon, authenticated;
comment on function private.copiar_correo() is 'Trigger de auth.users: crea el perfil de cada cuenta nueva y le copia el correo cuando cambia.';
create trigger copiar_correo after insert or update of email on auth.users
  for each row execute function private.copiar_correo();

-- Las cuentas que ya existían.
insert into public.perfiles (usuario_id, correo)
select id, coalesce(email, '') from auth.users
on conflict (usuario_id) do update set correo = excluded.correo;

-- ── Nunca sin administrador ─────────────────────────────────────────────────
create function private.proteger_ultimo_admin() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.rol <> 'admin' or (tg_op = 'UPDATE' and new.rol = 'admin') then
    return coalesce(new, old);
  end if;
  -- Se está borrando la empresa entera o la cuenta: no hay nada que proteger.
  if not exists (select 1 from public.empresas e where e.id = old.empresa_id)
     or not exists (select 1 from auth.users u where u.id = old.usuario_id) then
    return coalesce(new, old);
  end if;
  if not exists (
    select 1 from public.miembros m
    where m.empresa_id = old.empresa_id and m.rol = 'admin' and m.usuario_id <> old.usuario_id
  ) then
    raise exception 'La empresa no puede quedarse sin administrador' using errcode = 'P0001', hint = 'ultimo_admin';
  end if;
  return coalesce(new, old);
end
$$;
revoke execute on function private.proteger_ultimo_admin() from public, anon, authenticated;
comment on function private.proteger_ultimo_admin() is 'Trigger de miembros: impide quitar o degradar al último administrador de una empresa.';
create trigger proteger_ultimo_admin before update or delete on public.miembros
  for each row execute function private.proteger_ultimo_admin();
