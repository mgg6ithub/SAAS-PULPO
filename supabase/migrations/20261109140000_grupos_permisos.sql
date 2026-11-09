-- La tabla de grupos nació sin permisos para los usuarios (las tablas nuevas ya no los reciben solas):
-- sin esto, cualquier guardado con grupos fallaba y bloqueaba el resto. El RLS sigue decidiendo qué filas.
grant select, insert, update, delete on public.grupos to authenticated;
