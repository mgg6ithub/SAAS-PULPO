-- Trabajos fijados (DEV-025): el planificador respeta su hora y su técnico.
-- Columna nueva en una tabla que ya tiene empresa_id, RLS y permisos; el trigger
-- limitar_cambios_trabajador ya impide que el trabajador la cambie (compara toda la fila).
alter table public.trabajos add column fijado boolean not null default false;
comment on column public.trabajos.fijado is 'Fijado a su hora y su técnico: el planificador no lo mueve.';
