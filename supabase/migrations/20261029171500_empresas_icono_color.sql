-- Icono y color de cada empresa, para distinguirlas en el selector de empresas de la barra.
alter table public.empresas
  add column icono text not null default '',
  add column color bigint not null default 0;
comment on column public.empresas.icono is 'Clave del icono (iconosTipo de la app); vacío = el de su tipo.';
comment on column public.empresas.color is 'Color ARGB del icono; 0 = el morado de Pulpo.';
