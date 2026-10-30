-- Cada cuenta es de una marca (residencial o industrial) y solo entra en su app. La marca se fija la primera
-- vez que entra; las cuentas que ya existían se marcan por sus empresas (residencial si tiene alguna).
create table public.cuentas_marca (
  usuario_id uuid primary key references auth.users (id) on delete cascade,
  marca text not null check (marca in ('residencial', 'industrial')),
  created_at timestamptz not null default now()
);
comment on table public.cuentas_marca is 'Marca de cada cuenta: solo puede entrar en la app de esa marca. La escribe entrar(); nadie la cambia desde la app.';
alter table public.cuentas_marca enable row level security;
create policy "ver la marca de mi cuenta" on public.cuentas_marca for select to authenticated
  using (usuario_id = (select auth.uid()));

insert into public.cuentas_marca (usuario_id, marca)
select u.id,
  case when exists (select 1 from public.miembros m join public.empresas e on e.id = m.empresa_id
                    where m.usuario_id = u.id and e.marca = 'residencial') then 'residencial'
       when exists (select 1 from public.miembros m join public.empresas e on e.id = m.empresa_id
                    where m.usuario_id = u.id and e.marca = 'industrial') then 'industrial'
       else 'residencial' end
from auth.users u
on conflict do nothing;

create or replace function public.entrar(p_codigo text default null, p_marca text default 'residencial')
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
  -- La cuenta es de una sola marca: la primera app en la que entra la marca para siempre.
  insert into public.cuentas_marca (usuario_id, marca) values (u, p_marca) on conflict (usuario_id) do nothing;
  if (select cm.marca from public.cuentas_marca cm where cm.usuario_id = u) <> p_marca then
    raise exception 'Esta cuenta es de otra marca' using errcode = 'P0002';
  end if;
  if c is null then
    select nullif(raw_user_meta_data ->> 'invitacion', '') into c from auth.users where id = u;
  end if;
  creada := false;
  if c is not null then
    select * into i from public.invitaciones where codigo = c for update;
    if found and i.usada_por = u then
      -- Ya la aceptó esta cuenta (otra pestaña): se entra en esa empresa si sigue siendo miembro.
      select m.empresa_id into empresa from public.miembros m where m.usuario_id = u and m.empresa_id = i.empresa_id;
    elsif found and i.usada_por is null and i.caduca_en >= now()
          and (select e.marca from public.empresas e where e.id = i.empresa_id) = p_marca then
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
