-- DEV-014 y DEV-011: cómo entra la gente a una empresa y qué ve cada rol.
-- Administrador: todo (políticas *_admin de la migración inicial).
-- Trabajador: solo sus trabajos asignados, el cliente de cada uno y su propia ficha.

-- ── Un miembro con rol trabajador está ligado a su ficha ─────────────────────
alter table public.miembros add column trabajador_id uuid;
alter table public.miembros
  add foreign key (trabajador_id, empresa_id) references public.trabajadores (id, empresa_id)
  on delete set null (trabajador_id);
-- Una ficha solo puede tener una cuenta.
create unique index miembros_trabajador_unico on public.miembros (trabajador_id) where trabajador_id is not null;

-- ── Invitaciones ─────────────────────────────────────────────────────────────
create table public.invitaciones (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  -- 64 caracteres al azar: se manda en un enlace y vale una sola vez.
  codigo text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  rol text not null check (rol in ('admin', 'trabajador')),
  trabajador_id uuid,
  creada_por uuid default auth.uid() references auth.users (id) on delete set null,
  caduca_en timestamptz not null default now() + interval '7 days',
  usada_por uuid references auth.users (id) on delete set null,
  usada_en timestamptz,
  created_at timestamptz not null default now(),
  check (rol = 'admin' or trabajador_id is not null),
  foreign key (trabajador_id, empresa_id) references public.trabajadores (id, empresa_id) on delete cascade
);
create index invitaciones_empresa_id_idx on public.invitaciones (empresa_id);
create index invitaciones_trabajador_id_idx on public.invitaciones (trabajador_id);
create index invitaciones_creada_por_idx on public.invitaciones (creada_por);
create index invitaciones_usada_por_idx on public.invitaciones (usada_por);
comment on table public.invitaciones is 'Enlaces de un solo uso para unirse a una empresa como administrador o como trabajador (ficha concreta).';

alter table public.invitaciones enable row level security;
revoke all on public.invitaciones from anon;
-- El código, la caducidad y el uso no los elige quien crea la invitación.
grant select, delete on public.invitaciones to authenticated;
grant insert (empresa_id, rol, trabajador_id) on public.invitaciones to authenticated;

create policy invitaciones_select on public.invitaciones for select to authenticated
  using (private.es_admin(empresa_id));
create policy invitaciones_insert on public.invitaciones for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy invitaciones_delete on public.invitaciones for delete to authenticated
  using (private.es_admin(empresa_id));

-- Única puerta para entrar a una empresa ajena. Security definer porque quien acepta aún no es miembro;
-- por eso comprueba la sesión y el código dentro y solo la puede ejecutar quien ha iniciado sesión.
create function public.aceptar_invitacion(p_codigo text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  i public.invitaciones;
  u uuid := (select auth.uid());
begin
  if u is null then
    raise exception 'Hace falta iniciar sesión' using errcode = '28000';
  end if;
  select * into i from public.invitaciones where codigo = p_codigo for update;
  if not found or i.usada_por is not null or i.caduca_en < now() then
    raise exception 'Invitación no válida o caducada' using errcode = 'P0001';
  end if;
  insert into public.miembros (usuario_id, empresa_id, rol, trabajador_id)
  values (u, i.empresa_id, i.rol, i.trabajador_id)
  on conflict (usuario_id, empresa_id) do update
    set rol = case when public.miembros.rol = 'admin' then 'admin' else excluded.rol end,
        trabajador_id = coalesce(excluded.trabajador_id, public.miembros.trabajador_id);
  update public.invitaciones set usada_por = u, usada_en = now() where id = i.id;
  return i.empresa_id;
end
$$;
revoke execute on function public.aceptar_invitacion(text) from public, anon;
grant execute on function public.aceptar_invitacion(text) to authenticated;
comment on function public.aceptar_invitacion(text) is 'Une a la cuenta con sesión a la empresa de la invitación (un solo uso, 7 días).';

-- ── Rol trabajador: solo lo suyo ─────────────────────────────────────────────
create function private.mi_trabajador(p_empresa uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select m.trabajador_id from public.miembros m
  where m.empresa_id = p_empresa and m.usuario_id = (select auth.uid()) and m.rol = 'trabajador'
$$;
revoke execute on function private.mi_trabajador(uuid) from public, anon;
grant execute on function private.mi_trabajador(uuid) to authenticated;
comment on function private.mi_trabajador(uuid) is 'Ficha de trabajador de la cuenta con sesión en esa empresa (null si no es trabajador).';

create policy trabajadores_propio on public.trabajadores for select to authenticated
  using (id = private.mi_trabajador(empresa_id));
create policy trabajo_trabajadores_propio on public.trabajo_trabajadores for select to authenticated
  using (trabajador_id = private.mi_trabajador(empresa_id));

-- Un trabajo es mío si tengo una asignación visible (la política anterior solo deja ver las mías).
create policy trabajos_asignados_select on public.trabajos for select to authenticated
  using (exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id));
create policy trabajos_asignados_update on public.trabajos for update to authenticated
  using (exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id))
  with check (exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id));
create policy clientes_de_mis_trabajos on public.clientes for select to authenticated
  using (exists (select 1 from public.trabajos t where t.cliente_id = clientes.id));
create policy historial_de_mis_trabajos on public.trabajo_historial for all to authenticated
  using (exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajo_historial.trabajo_id))
  with check (exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajo_historial.trabajo_id));

-- El trabajador solo cambia el estado y las fechas; el resto del trabajo es del administrador.
create function private.limitar_cambios_trabajador() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is null or private.es_admin(new.empresa_id) then
    return new;
  end if;
  if (to_jsonb(new) - 'estado' - 'ultimo' - 'proximo' - 'updated_at')
     <> (to_jsonb(old) - 'estado' - 'ultimo' - 'proximo' - 'updated_at') then
    raise exception 'El trabajador solo puede cambiar el estado y las fechas del trabajo' using errcode = '42501';
  end if;
  return new;
end
$$;
revoke execute on function private.limitar_cambios_trabajador() from public, anon;
grant execute on function private.limitar_cambios_trabajador() to authenticated;
comment on function private.limitar_cambios_trabajador() is 'Trigger de trabajos: un trabajador solo puede cambiar estado, ultimo y proximo.';
create trigger limitar_cambios_trabajador before update on public.trabajos
  for each row execute function private.limitar_cambios_trabajador();
