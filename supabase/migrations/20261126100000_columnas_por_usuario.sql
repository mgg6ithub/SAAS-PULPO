-- Pultec: cada cuenta guarda cómo ha dejado las columnas de cada tabla (orden y cuáles ve), para encontrarlas
-- igual al volver a entrar. Es de la persona, como el resto del perfil; la escribe solo ella (perfiles_update).
alter table public.perfiles
  add column columnas jsonb not null default '{}'
    constraint perfiles_columnas_objeto check (jsonb_typeof(columnas) = 'object' and pg_column_size(columnas) < 32000);

comment on column public.perfiles.columnas is
  'Columnas de las tablas de la app por cuenta: {tabla: {orden: [títulos], ver: {título: bool}}}.';

grant insert (columnas), update (columnas) on public.perfiles to authenticated;
