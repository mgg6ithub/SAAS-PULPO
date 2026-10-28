-- DEV-021: informes del trabajador en la base y fotos en Storage (bucket privado `fotos`).

-- ── Informes ────────────────────────────────────────────────────────────────
create table public.informes (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  trabajo_id uuid not null,
  trabajador_id uuid,
  resultado smallint not null default 0 check (resultado between 0 and 2),
  notas text not null default '',
  fotos text[] not null default '{}',
  creado_por uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete cascade,
  foreign key (trabajador_id, empresa_id) references public.trabajadores (id, empresa_id)
    on delete set null (trabajador_id)
);
create index informes_empresa_id_idx on public.informes (empresa_id);
create index informes_trabajo_id_idx on public.informes (trabajo_id, created_at desc);
create index informes_trabajador_id_idx on public.informes (trabajador_id);
create index informes_creado_por_idx on public.informes (creado_por);
comment on table public.informes is 'Informe de un trabajo hecho: resultado (0 correcto, 1 con incidencias, 2 no se pudo), notas y rutas de sus fotos en Storage.';

alter table public.informes enable row level security;
revoke all on public.informes from anon, authenticated;
grant select, insert, update, delete on public.informes to authenticated;

-- El administrador, todo; el trabajador ve los informes de sus trabajos y crea los suyos.
create policy informes_select on public.informes for select to authenticated
  using (
    private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = informes.trabajo_id)
  );
create policy informes_insert on public.informes for insert to authenticated
  with check (
    private.es_admin(empresa_id)
    or (
      trabajador_id = private.mi_trabajador(empresa_id)
      and exists (
        select 1 from public.trabajo_trabajadores tt
        where tt.trabajo_id = informes.trabajo_id and tt.trabajador_id = informes.trabajador_id
      )
    )
  );
create policy informes_update on public.informes for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy informes_delete on public.informes for delete to authenticated
  using (private.es_admin(empresa_id));

-- ── Fotos en Storage ────────────────────────────────────────────────────────
-- Rutas: <empresa>/clientes/<archivo>, <empresa>/trabajadores/<archivo>, <empresa>/informes/<informe>/<archivo>.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 2097152, array['image/png', 'image/jpeg', 'image/webp']);

-- Leer: fotos de clientes y trabajadores, cualquier miembro; las de un informe, quien puede ver el informe.
create policy fotos_select on storage.objects for select to authenticated
  using (
    bucket_id = 'fotos'
    and (
      private.es_admin(((storage.foldername(name))[1])::uuid)
      or (
        (storage.foldername(name))[2] in ('clientes', 'trabajadores')
        and private.es_miembro(((storage.foldername(name))[1])::uuid)
      )
      or (
        (storage.foldername(name))[2] = 'informes'
        and exists (select 1 from public.informes i where i.id::text = (storage.foldername(name))[3])
      )
    )
  );
-- Subir: el administrador, todo; el trabajador, solo fotos de informes de su empresa.
create policy fotos_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'fotos'
    and (
      private.es_admin(((storage.foldername(name))[1])::uuid)
      or (
        (storage.foldername(name))[2] = 'informes'
        and private.mi_trabajador(((storage.foldername(name))[1])::uuid) is not null
      )
    )
  );
create policy fotos_update on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and private.es_admin(((storage.foldername(name))[1])::uuid))
  with check (bucket_id = 'fotos' and private.es_admin(((storage.foldername(name))[1])::uuid));
create policy fotos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and private.es_admin(((storage.foldername(name))[1])::uuid));

comment on column public.clientes.foto is 'Ruta de la foto en el bucket fotos (o PNG base64 antiguo, que la app sube a Storage al abrir).';
comment on column public.trabajadores.foto is 'Ruta de la foto en el bucket fotos (o PNG base64 antiguo, que la app sube a Storage al abrir).';
