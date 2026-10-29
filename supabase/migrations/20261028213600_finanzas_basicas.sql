-- DEV-017: finanzas básicas SIN valor fiscal (presupuestos y facturas proforma; la factura legal con
-- Verifactu queda para después). Todo solo para el administrador: el trabajador no ve importes.

set check_function_bodies = off;

-- ── Precio de cada trabajo o plantilla (tabla aparte: el trabajador lee `trabajos`, no los precios) ──
create table public.trabajo_precios (
  trabajo_id uuid primary key,
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  precio numeric(12, 2) not null default 0 check (precio >= 0),
  iva numeric(5, 2) not null default 21 check (iva between 0 and 100),
  foreign key (trabajo_id, empresa_id) references public.trabajos (id, empresa_id) on delete cascade
);
create index trabajo_precios_empresa_id_idx on public.trabajo_precios (empresa_id);
comment on table public.trabajo_precios is 'Importe (sin IVA) y % de IVA de cada trabajo o plantilla. Solo administradores.';

alter table public.trabajo_precios enable row level security;
revoke all on public.trabajo_precios from anon, authenticated;
grant select, insert, update, delete on public.trabajo_precios to authenticated;
create policy trabajo_precios_admin on public.trabajo_precios for all to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));

-- ── Presupuestos y facturas proforma ──
create table public.documentos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  tipo text not null check (tipo in ('presupuesto', 'proforma')),
  serie integer not null default extract(year from current_date)::integer,
  numero integer not null default 0,
  cliente_id uuid,
  fecha date not null default current_date,
  vence date,
  cobrada_el date,
  lineas jsonb not null default '[]' check (jsonb_typeof(lineas) = 'array'),
  notas text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (empresa_id, tipo, serie, numero),
  foreign key (cliente_id, empresa_id) references public.clientes (id, empresa_id) on delete set null (cliente_id)
);
create index documentos_cliente_id_idx on public.documentos (cliente_id);
create index documentos_empresa_fecha_idx on public.documentos (empresa_id, fecha desc);
comment on table public.documentos is 'Presupuestos y facturas proforma (sin valor fiscal). Líneas en JSON: concepto, cantidad, precio, iva y, si sale de un trabajo hecho, trabajo_id y dia.';

alter table public.documentos enable row level security;
revoke all on public.documentos from anon, authenticated;
grant select, insert, update, delete on public.documentos to authenticated;
create policy documentos_admin on public.documentos for all to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));

-- Número correlativo por empresa, tipo y año, puesto por la base (dos altas a la vez no se pisan).
create function private.numerar_documento() returns trigger
language plpgsql set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtext(new.empresa_id::text || new.tipo || new.serie::text));
  select coalesce(max(d.numero), 0) + 1 into new.numero
  from public.documentos d
  where d.empresa_id = new.empresa_id and d.tipo = new.tipo and d.serie = new.serie;
  return new;
end $$;
comment on function private.numerar_documento() is 'Pone el siguiente número correlativo (empresa, tipo, año) al crear un presupuesto o proforma.';
create trigger documentos_numero before insert on public.documentos
  for each row execute function private.numerar_documento();

create trigger documentos_updated_at before update on public.documentos
  for each row execute function private.tocar_updated_at();
