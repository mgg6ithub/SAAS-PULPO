-- Identidad visual del activo y de cada componente; conserva las políticas existentes.
alter table public.activos
  add column icono text not null default 'brazo'
  constraint activos_icono_valido check (char_length(icono) between 1 and 40);
comment on column public.activos.icono is 'Clave estable del icono industrial elegido; brazo por defecto para activos anteriores.';
