-- Equipos de los clientes y vencimientos legales (DEV-028).
-- equipos: ficha propia de cada ascensor, caldera, extintor… (el trabajo se enlaza con equipo_id).
-- vencimientos: inspecciones y revisiones obligatorias con su fecha y cuántos días antes avisar.
-- documentos: bucket privado aparte (certificados en PDF y fotos), solo para el administrador.

create table public.equipos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  cliente_id uuid not null references public.clientes (id) on delete cascade,
  tipo text not null default 'Otro',
  nombre text not null default '',
  marca text not null default '',
  modelo text not null default '',
  numero_serie text not null default '',
  ubicacion text not null default '',
  notas text not null default '',
  instalacion date,
  estado smallint not null default 0 check (estado between 0 and 2),
  documentos text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vencimientos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  equipo_id uuid not null references public.equipos (id) on delete cascade,
  nombre text not null default '',
  vence date not null,
  avisar_dias integer not null default 30 check (avisar_dias >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.trabajos add column equipo_id uuid references public.equipos (id) on delete set null;

create index equipos_empresa_id_idx on public.equipos (empresa_id);
create index equipos_cliente_id_idx on public.equipos (cliente_id);
create index vencimientos_empresa_id_idx on public.vencimientos (empresa_id);
create index vencimientos_equipo_id_idx on public.vencimientos (equipo_id);
create index trabajos_equipo_id_idx on public.trabajos (equipo_id);

create trigger tocar_updated_at before update on public.equipos
  for each row execute function private.tocar_updated_at();
create trigger tocar_updated_at before update on public.vencimientos
  for each row execute function private.tocar_updated_at();

alter table public.equipos enable row level security;
alter table public.vencimientos enable row level security;

-- equipos: el administrador todo; el trabajador ve los equipos de sus trabajos.
create policy equipos_select on public.equipos for select to authenticated
  using (
    private.es_admin(empresa_id)
    or exists (
      select 1 from public.trabajos t join public.trabajo_trabajadores tt on tt.trabajo_id = t.id
      where t.equipo_id = equipos.id
    )
  );
create policy equipos_insert on public.equipos for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy equipos_update on public.equipos for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy equipos_delete on public.equipos for delete to authenticated
  using (private.es_admin(empresa_id));

-- vencimientos: solo el administrador.
create policy vencimientos_admin on public.vencimientos for all to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));

grant select, insert, update, delete on public.equipos, public.vencimientos to authenticated;

comment on table public.equipos is 'Equipos de los clientes (ascensores, calderas, extintores…): datos, estado y documentos.';
comment on table public.vencimientos is 'Vencimientos legales de cada equipo (inspecciones, revisiones obligatorias) con días de aviso.';
comment on column public.trabajos.equipo_id is 'Equipo sobre el que se hace el trabajo (null = sin equipo).';
comment on column public.equipos.documentos is 'Rutas de sus documentos en el bucket documentos (<empresa>/equipos/<equipo>/<archivo>).';

-- Documentos: PDF e imágenes hasta 10 MB, solo el administrador de la empresa de la ruta.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos', 'documentos', false, 10485760, array['application/pdf', 'image/png', 'image/jpeg', 'image/webp']);

create policy documentos_select on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and private.es_admin(((storage.foldername(name))[1])::uuid));
create policy documentos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and private.es_admin(((storage.foldername(name))[1])::uuid));
create policy documentos_update on storage.objects for update to authenticated
  using (bucket_id = 'documentos' and private.es_admin(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'documentos' and private.es_admin(((storage.foldername(name))[1])::uuid));
create policy documentos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'documentos' and private.es_admin(((storage.foldername(name))[1])::uuid));
