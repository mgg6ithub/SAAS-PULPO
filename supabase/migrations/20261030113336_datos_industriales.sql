-- iPultec (IPT-000): misma base que Pultec, separada por empresa. Todo es aditivo:
-- las empresas de Pultec quedan con marca 'residencial' y las columnas nuevas de trabajos en null.
-- Tipo de mantenimiento (smallint, como los enums de la app): 0 preventivo, 1 correctivo no crítico,
-- 2 correctivo crítico.

-- ── Marca de cada empresa: cada app solo muestra las suyas ───────────────────
alter table public.empresas
  add column marca text not null default 'residencial' check (marca in ('residencial', 'industrial'));
comment on column public.empresas.marca is 'App a la que pertenece la empresa: residencial (Pultec) o industrial (iPultec).';

-- ── Activos: árbol activo → componente → subcomponente (padre_id) ───────────
create table public.activos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  padre_id uuid,
  tag text not null default '',
  nombre text not null default '',
  fabricante text not null default '',
  modelo text not null default '',
  numero_serie text not null default '',
  division text not null default '',
  repuestos text not null default '',
  notas text not null default '',
  horas numeric(12, 1) not null default 0 check (horas >= 0),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, empresa_id),
  foreign key (padre_id, empresa_id) references public.activos (id, empresa_id) on delete cascade,
  check (padre_id is distinct from id)
);
create index activos_empresa_id_idx on public.activos (empresa_id);
create index activos_padre_id_idx on public.activos (padre_id);

-- ── Trabajos = órdenes de trabajo (OT) ───────────────────────────────────────
alter table public.trabajos
  add column tipo_mantenimiento smallint check (tipo_mantenimiento between 0 and 2),
  add column activo_id uuid,
  add constraint trabajos_activo_fk foreign key (activo_id, empresa_id)
    references public.activos (id, empresa_id) on delete set null (activo_id);
create index trabajos_activo_id_idx on public.trabajos (activo_id);
comment on column public.trabajos.tipo_mantenimiento is 'OT industrial: 0 preventivo, 1 correctivo no crítico, 2 correctivo crítico (null en Pultec).';
comment on column public.trabajos.activo_id is 'Activo o componente sobre el que se hace la OT (null = sin activo). La duración es duracion_min.';

-- ── Planes de mantenimiento por componente ──────────────────────────────────
create table public.planes_mantenimiento (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  activo_id uuid not null,
  nombre text not null default '',
  tipo_mantenimiento smallint not null default 0 check (tipo_mantenimiento between 0 and 2),
  cada_dias integer check (cada_dias > 0),
  cada_horas integer check (cada_horas > 0),
  categoria text not null default '',
  repuestos text not null default '',
  procedimiento text not null default '',
  duracion_min integer not null default 60 check (duracion_min > 0),
  ultimo date,
  ultimo_horas numeric(12, 1),
  proximo date,
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (activo_id, empresa_id) references public.activos (id, empresa_id) on delete cascade
);
create index planes_mantenimiento_empresa_id_idx on public.planes_mantenimiento (empresa_id);
create index planes_mantenimiento_activo_id_idx on public.planes_mantenimiento (activo_id);

-- ── Incidencias: avisos de avería con gravedad y fotos; pueden acabar en OT ─
create table public.incidencias (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  activo_id uuid not null,
  trabajo_id uuid,
  descripcion text not null default '',
  gravedad smallint not null default 1 check (gravedad between 0 and 2),
  estado smallint not null default 0 check (estado between 0 and 2),
  fotos text[] not null default '{}',
  creada_por uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (activo_id, empresa_id) references public.activos (id, empresa_id) on delete cascade,
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete set null (trabajo_id)
);
create index incidencias_empresa_id_idx on public.incidencias (empresa_id);
create index incidencias_activo_id_idx on public.incidencias (activo_id);
create index incidencias_trabajo_id_idx on public.incidencias (trabajo_id);
create index incidencias_creada_por_idx on public.incidencias (creada_por);

-- ── Horas de uso: lecturas del contador de cada activo ──────────────────────
create table public.horas_uso (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  activo_id uuid not null,
  fecha date not null default current_date,
  horas numeric(12, 1) not null check (horas >= 0),
  creada_por uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  foreign key (activo_id, empresa_id) references public.activos (id, empresa_id) on delete cascade
);
create index horas_uso_empresa_id_idx on public.horas_uso (empresa_id);
create index horas_uso_activo_fecha_idx on public.horas_uso (activo_id, fecha);
create index horas_uso_creada_por_idx on public.horas_uso (creada_por);

create trigger tocar_updated_at before update on public.activos
  for each row execute function private.tocar_updated_at();
create trigger tocar_updated_at before update on public.planes_mantenimiento
  for each row execute function private.tocar_updated_at();
create trigger tocar_updated_at before update on public.incidencias
  for each row execute function private.tocar_updated_at();

-- ── RLS: el administrador, todo; el técnico ve las máquinas y sus planes de su empresa
-- y da de alta incidencias y lecturas de horas (solo ve las suyas). ─────────────
alter table public.activos enable row level security;
alter table public.planes_mantenimiento enable row level security;
alter table public.incidencias enable row level security;
alter table public.horas_uso enable row level security;

create policy activos_select on public.activos for select to authenticated
  using (private.es_miembro(empresa_id));
create policy activos_insert on public.activos for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy activos_update on public.activos for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy activos_delete on public.activos for delete to authenticated
  using (private.es_admin(empresa_id));

create policy planes_mantenimiento_select on public.planes_mantenimiento for select to authenticated
  using (private.es_miembro(empresa_id));
create policy planes_mantenimiento_insert on public.planes_mantenimiento for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy planes_mantenimiento_update on public.planes_mantenimiento for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy planes_mantenimiento_delete on public.planes_mantenimiento for delete to authenticated
  using (private.es_admin(empresa_id));

create policy incidencias_select on public.incidencias for select to authenticated
  using (private.es_admin(empresa_id) or (creada_por = (select auth.uid()) and private.es_miembro(empresa_id)));
create policy incidencias_insert on public.incidencias for insert to authenticated
  with check (private.es_miembro(empresa_id) and creada_por = (select auth.uid()));
create policy incidencias_update on public.incidencias for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy incidencias_delete on public.incidencias for delete to authenticated
  using (private.es_admin(empresa_id));

create policy horas_uso_select on public.horas_uso for select to authenticated
  using (private.es_admin(empresa_id) or (creada_por = (select auth.uid()) and private.es_miembro(empresa_id)));
create policy horas_uso_insert on public.horas_uso for insert to authenticated
  with check (private.es_miembro(empresa_id) and creada_por = (select auth.uid()));
create policy horas_uso_update on public.horas_uso for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy horas_uso_delete on public.horas_uso for delete to authenticated
  using (private.es_admin(empresa_id));

revoke all on public.activos, public.planes_mantenimiento, public.incidencias, public.horas_uso from anon;
grant select, insert, update, delete
  on public.activos, public.planes_mantenimiento, public.incidencias, public.horas_uso to authenticated;

comment on table public.activos is 'iPultec: máquinas y sus componentes en árbol (padre_id), con tag, fabricante, modelo y horas de uso.';
comment on table public.planes_mantenimiento is 'iPultec: mantenimientos periódicos de cada componente (cada N días u horas), con tipo, categoría, repuestos y procedimiento.';
comment on table public.incidencias is 'iPultec: avisos de avería de un activo con gravedad (0-2) y fotos; estado 0 abierta, 1 con OT, 2 cerrada.';
comment on table public.horas_uso is 'iPultec: lecturas del contador de horas de cada activo.';
comment on column public.planes_mantenimiento.categoria is 'Categoría de técnico que puede hacerlo (= competencia de trabajadores).';
