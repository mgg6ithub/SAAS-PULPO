-- Pultec: breve descripción opcional de cada activo o componente, visible bajo su nombre.
alter table public.activos add column if not exists descripcion text not null default '';
