-- Esquema inicial de Pultec (antes Pulpo): empresas, miembros y los datos de models.dart.
-- Multiempresa: cada fila lleva empresa_id y RLS. Una cuenta puede estar en varias empresas
-- con un rol distinto en cada una (tabla miembros).
-- Enums de la app = smallint con el mismo índice que en Dart (EstadoHoy, Criticidad, ...).
-- Colores = ARGB, no caben en int4, por eso bigint.

-- Las funciones citan miembros, que se crea más abajo.
set check_function_bodies = off;

-- ── Funciones de apoyo (schema privado, no expuesto por la API) ──────────────
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create function private.es_miembro(p_empresa uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.miembros m
    where m.empresa_id = p_empresa and m.usuario_id = (select auth.uid())
  )
$$;

create function private.es_admin(p_empresa uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.miembros m
    where m.empresa_id = p_empresa and m.usuario_id = (select auth.uid()) and m.rol = 'admin'
  )
$$;

create function private.empresa_sin_miembros(p_empresa uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.miembros m where m.empresa_id = p_empresa)
$$;

create function private.tocar_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end
$$;

revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;

-- ── Empresas y miembros ──────────────────────────────────────────────────────
create table public.empresas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null default '',
  creada_por uuid not null default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.miembros (
  usuario_id uuid not null references auth.users (id) on delete cascade,
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  rol text not null check (rol in ('admin', 'trabajador')),
  created_at timestamptz not null default now(),
  primary key (usuario_id, empresa_id)
);
create index miembros_empresa_id_idx on public.miembros (empresa_id);

-- ── Datos de la empresa (columnas = models.dart) ─────────────────────────────
create table public.clientes (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nombre text not null default '',
  cif text not null default '',
  direccion text not null default '',
  ciudad text not null default '',
  cp text not null default '',
  provincia text not null default '',
  telefono text not null default '',
  email text not null default '',
  contacto text not null default '',
  telefono_contacto text not null default '',
  notas text not null default '',
  foto text not null default '', -- PNG base64 como en el prototipo; pasar a Storage más adelante
  activa boolean not null default true,
  fecha_alta timestamptz not null default now(),
  color bigint not null default 0,
  lat double precision,
  lng double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, empresa_id)
);

create table public.trabajadores (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nombre text not null default '',
  apellidos text not null default '',
  telefono text not null default '',
  email text not null default '',
  info text not null default '',
  titulos text not null default '',
  foto text not null default '',
  competencias text[] not null default '{}',
  activo boolean not null default true,
  estado_hoy smallint not null default 0 check (estado_hoy between 0 and 2),
  color bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, empresa_id)
);

-- Tarea del modelo: plantilla, trabajo o subtrabajo (padre_id).
create table public.trabajos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  cliente_id uuid,
  plantilla boolean not null default false,
  color bigint,
  plantilla_id uuid,
  padre_id uuid,
  nombre text not null default '',
  tipo text not null default 'Otro',
  marca text not null default '',
  modelo text not null default '',
  numero_serie text not null default '',
  ubicacion text not null default '',
  notas text not null default '',
  instalacion date,
  ultimo date,
  proximo date,
  solicitud date,
  inicio_min integer,
  ventana_desde_min integer,
  ventana_hasta_min integer,
  duracion_min integer not null default 60,
  estado_maquina smallint not null default 0 check (estado_maquina between 0 and 2),
  estado smallint not null default 0 check (estado between 0 and 3),
  criticidad smallint not null default 2 check (criticidad between 0 and 3),
  periodicidad smallint not null default 1 check (periodicidad between 0 and 5),
  activa boolean not null default true,
  competencias text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, empresa_id),
  -- Las referencias llevan empresa_id: un trabajo no puede apuntar a datos de otra empresa.
  foreign key (cliente_id, empresa_id) references public.clientes (id, empresa_id)
    on delete set null (cliente_id),
  foreign key (plantilla_id, empresa_id) references public.trabajos (id, empresa_id)
    on delete set null (plantilla_id),
  foreign key (padre_id, empresa_id) references public.trabajos (id, empresa_id)
    on delete cascade
);
create index trabajos_empresa_proximo_idx on public.trabajos (empresa_id, proximo);
create index trabajos_cliente_id_idx on public.trabajos (cliente_id);
create index trabajos_plantilla_id_idx on public.trabajos (plantilla_id);
create index trabajos_padre_id_idx on public.trabajos (padre_id);

create table public.trabajo_trabajadores (
  trabajo_id uuid not null,
  trabajador_id uuid not null,
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  primary key (trabajo_id, trabajador_id),
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete cascade,
  foreign key (trabajador_id, empresa_id) references public.trabajadores (id, empresa_id) on delete cascade
);
create index trabajo_trabajadores_trabajador_id_idx on public.trabajo_trabajadores (trabajador_id);
create index trabajo_trabajadores_empresa_id_idx on public.trabajo_trabajadores (empresa_id);

-- Días en que se hizo cada trabajo (Tarea.historial).
create table public.trabajo_historial (
  trabajo_id uuid not null,
  dia date not null,
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  primary key (trabajo_id, dia),
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete cascade
);
create index trabajo_historial_empresa_id_idx on public.trabajo_historial (empresa_id);

create table public.automatizaciones (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  trabajo_id uuid not null,
  nombre text not null default '',
  asunto text not null default '',
  cuerpo text not null default '',
  activa boolean not null default true,
  a_trabajadores boolean not null default true,
  a_cliente boolean not null default false,
  disparador smallint not null default 0 check (disparador between 0 and 3),
  cantidad integer not null default 1,
  en_horas boolean not null default false,
  extras text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete cascade
);
create index automatizaciones_trabajo_id_idx on public.automatizaciones (trabajo_id);
create index automatizaciones_empresa_id_idx on public.automatizaciones (empresa_id);

create table public.etiquetas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nombre text not null default '',
  color bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index clientes_empresa_id_idx on public.clientes (empresa_id);
create index trabajadores_empresa_id_idx on public.trabajadores (empresa_id);
create index etiquetas_empresa_id_idx on public.etiquetas (empresa_id);

-- ── updated_at automático ────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array['empresas', 'clientes', 'trabajadores', 'trabajos', 'automatizaciones', 'etiquetas'] loop
    execute format(
      'create trigger tocar_updated_at before update on public.%I
       for each row execute function private.tocar_updated_at()', t);
  end loop;
end $$;

-- ── Seguridad: RLS en todo y permisos solo para usuarios con sesión ──────────
alter table public.empresas enable row level security;
alter table public.miembros enable row level security;
alter table public.clientes enable row level security;
alter table public.trabajadores enable row level security;
alter table public.trabajos enable row level security;
alter table public.trabajo_trabajadores enable row level security;
alter table public.trabajo_historial enable row level security;
alter table public.automatizaciones enable row level security;
alter table public.etiquetas enable row level security;

grant select, insert, update, delete on
  public.empresas, public.miembros, public.clientes, public.trabajadores, public.trabajos,
  public.trabajo_trabajadores, public.trabajo_historial, public.automatizaciones, public.etiquetas
  to authenticated;

-- empresas: quien la crea la ve (hace falta para el insert ... returning); luego, sus miembros.
create policy empresas_select on public.empresas for select to authenticated
  using (creada_por = (select auth.uid()) or private.es_miembro(id));
create policy empresas_insert on public.empresas for insert to authenticated
  with check (creada_por = (select auth.uid()));
create policy empresas_update on public.empresas for update to authenticated
  using (private.es_admin(id)) with check (private.es_admin(id));
create policy empresas_delete on public.empresas for delete to authenticated
  using (private.es_admin(id));

-- miembros: cada cuenta ve los suyos; el admin ve y gestiona los de su empresa.
-- El creador de una empresa vacía se añade a sí mismo como admin (primer miembro).
create policy miembros_select on public.miembros for select to authenticated
  using (usuario_id = (select auth.uid()) or private.es_admin(empresa_id));
create policy miembros_insert on public.miembros for insert to authenticated
  with check (
    private.es_admin(empresa_id)
    or (
      usuario_id = (select auth.uid()) and rol = 'admin'
      and private.empresa_sin_miembros(empresa_id)
      and exists (
        select 1 from public.empresas e
        where e.id = empresa_id and e.creada_por = (select auth.uid())
      )
    )
  );
create policy miembros_update on public.miembros for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy miembros_delete on public.miembros for delete to authenticated
  using (private.es_admin(empresa_id));

-- Resto de tablas: por ahora solo el administrador de la empresa (el trabajador, en DEV-011).
do $$
declare t text;
begin
  foreach t in array array[
    'clientes', 'trabajadores', 'trabajos', 'trabajo_trabajadores',
    'trabajo_historial', 'automatizaciones', 'etiquetas'
  ] loop
    execute format(
      'create policy %I on public.%I for all to authenticated
       using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id))',
      t || '_admin', t);
  end loop;
end $$;
