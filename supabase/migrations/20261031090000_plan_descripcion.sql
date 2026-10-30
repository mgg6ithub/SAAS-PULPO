-- iPultec: breve descripción de cada mantenimiento, visible en la lista del activo.
alter table public.planes_mantenimiento add column if not exists descripcion text not null default '';
