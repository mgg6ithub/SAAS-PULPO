-- La tabla festivos se creó sin permisos para authenticated (los privilegios por defecto están revocados),
-- así que la carga de la empresa fallaba al leerla. Las políticas RLS siguen limitando qué filas ve cada uno.
grant select, insert, update, delete on public.festivos to authenticated;
