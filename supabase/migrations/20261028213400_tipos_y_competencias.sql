-- Tipos de trabajo y competencias editables por empresa (DEV-027).
-- Los ve todo miembro de la empresa (el trabajador los necesita para los colores e iconos);
-- solo el administrador los cambia. Una política por acción.

create table public.tipos_trabajo (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nombre text not null default '',
  clave text not null default 'otro',
  color bigint not null default 0,
  competencia text,
  retraso_min integer not null default 15,
  orden integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.competencias (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nombre text not null default '',
  orden integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tipos_trabajo_empresa_id_idx on public.tipos_trabajo (empresa_id);
create index competencias_empresa_id_idx on public.competencias (empresa_id);

create trigger tocar_updated_at before update on public.tipos_trabajo
  for each row execute function private.tocar_updated_at();
create trigger tocar_updated_at before update on public.competencias
  for each row execute function private.tocar_updated_at();

alter table public.tipos_trabajo enable row level security;
alter table public.competencias enable row level security;

do $$
declare t text;
begin
  foreach t in array array['tipos_trabajo', 'competencias'] loop
    execute format('create policy %I on public.%I for select to authenticated using (private.es_miembro(empresa_id))',
      t || '_select', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (private.es_admin(empresa_id))',
      t || '_insert', t);
    execute format('create policy %I on public.%I for update to authenticated
      using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id))', t || '_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (private.es_admin(empresa_id))',
      t || '_delete', t);
  end loop;
end $$;

grant select, insert, update, delete on public.tipos_trabajo, public.competencias to authenticated;

comment on table public.tipos_trabajo is 'Tipos de trabajo de la empresa (nombre, icono, color y competencia que pide); editables en Ajustes.';
comment on table public.competencias is 'Competencias de la empresa que se asignan a trabajadores y trabajos; editables en Ajustes.';
