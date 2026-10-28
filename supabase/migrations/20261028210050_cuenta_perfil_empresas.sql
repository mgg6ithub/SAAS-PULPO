-- DEV-018 · Cuenta, perfil y empresas: datos y tipo de la empresa, y perfil de cada cuenta.

-- ── Datos de la empresa ─────────────────────────────────────────────────────
alter table public.empresas
  add column tipo text not null default '',
  add column cif text not null default '',
  add column direccion text not null default '',
  add column telefono text not null default '',
  add column logo text;

comment on column public.empresas.tipo is 'A qué se dedica (Ascensores, Calderas, Jardinería, Limpieza o Varios): decide las plantillas con las que arranca.';
comment on column public.empresas.logo is 'Logo pequeño en PNG base64 (la app lo reduce a 256 px antes de guardarlo).';

-- ── Perfil de la cuenta ─────────────────────────────────────────────────────
-- Es de la persona, no de una empresa: por eso no lleva empresa_id (una cuenta puede estar en varias).
create table public.perfiles (
  usuario_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  nombre text not null default '',
  foto text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.perfiles is 'Nombre y foto de cada cuenta (salen en Mi cuenta, en los emails y en las invitaciones). Lo ve la propia cuenta y los administradores de sus empresas.';

create trigger tocar_updated_at before update on public.perfiles
  for each row execute function private.tocar_updated_at();

alter table public.perfiles enable row level security;

revoke all on public.perfiles from anon, authenticated;
grant select, insert, update, delete on public.perfiles to authenticated;

create policy perfiles_select on public.perfiles for select to authenticated
  using (
    usuario_id = (select auth.uid())
    or exists (
      select 1 from public.miembros m
      where m.usuario_id = perfiles.usuario_id and private.es_admin(m.empresa_id)
    )
  );

create policy perfiles_insert on public.perfiles for insert to authenticated
  with check (usuario_id = (select auth.uid()));

create policy perfiles_update on public.perfiles for update to authenticated
  using (usuario_id = (select auth.uid()))
  with check (usuario_id = (select auth.uid()));

create policy perfiles_delete on public.perfiles for delete to authenticated
  using (usuario_id = (select auth.uid()));
