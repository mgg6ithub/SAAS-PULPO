-- DEV-029: el informe pasa a ser el parte de trabajo (material, tiempo y firma del cliente).
alter table public.informes
  add column material text not null default '',
  add column minutos integer check (minutos is null or minutos between 0 and 10080),
  add column firma text,
  add column firmante text not null default '';

comment on column public.informes.material is 'Material usado en el trabajo (texto libre).';
comment on column public.informes.minutos is 'Tiempo dedicado, en minutos.';
comment on column public.informes.firma is 'Ruta en el bucket fotos de la firma del cliente (PNG), o null si no firmó.';
comment on column public.informes.firmante is 'Nombre de quien firma el parte por parte del cliente.';
