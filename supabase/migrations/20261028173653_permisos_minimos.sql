-- Permisos mínimos. Supabase da a anon y authenticated todo (incluido TRUNCATE) en cada tabla nueva de public,
-- y los permisos por columna no sirven si la tabla ya tiene el permiso entero.
-- Aquí se quita todo y se da solo lo que se usa; la seguridad de filas (RLS) decide el resto.
revoke all on all tables in schema public from anon, authenticated;

grant select, insert, update, delete on
  public.empresas, public.miembros, public.clientes, public.trabajadores, public.trabajos,
  public.trabajo_trabajadores, public.trabajo_historial, public.automatizaciones, public.etiquetas
  to authenticated;

-- Invitaciones: el código, la caducidad y el uso los pone la base, no quien invita.
grant select, delete on public.invitaciones to authenticated;
grant insert (empresa_id, rol, trabajador_id) on public.invitaciones to authenticated;

-- Las tablas que se creen después no reciben permisos solas: cada migración los da explícitamente.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
