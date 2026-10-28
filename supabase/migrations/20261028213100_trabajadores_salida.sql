-- Punto de salida de cada técnico (DEV-025): de dónde sale y adónde vuelve cada día.
-- Columnas nuevas en una tabla con empresa_id, RLS y permisos ya puestos.
alter table public.trabajadores
  add column salida text not null default '',
  add column salida_lat double precision,
  add column salida_lng double precision;
comment on column public.trabajadores.salida is 'Dirección de salida y vuelta del técnico (su casa o la oficina); vacío = el almacén.';
comment on column public.trabajadores.salida_lat is 'Latitud del punto de salida (null = sin ubicar).';
comment on column public.trabajadores.salida_lng is 'Longitud del punto de salida (null = sin ubicar).';
