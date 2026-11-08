alter table public.planes_mantenimiento add column color bigint
  check (color is null or color between 0 and 4294967295);
comment on column public.planes_mantenimiento.color is 'Color ARGB opcional elegido por el usuario; independiente de la prioridad y del tipo de OT.';
