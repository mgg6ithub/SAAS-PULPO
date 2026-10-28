-- Con SMTP no hay clave de idempotencia como en una API: antes de enviar, la función «reclama» cada fila
-- (pendiente → enviando) con una actualización condicionada, y solo quien la gana la envía.
-- Si la función se cae a medias, la fila vuelve a estar disponible pasados 10 minutos.
alter table public.envios_automatizacion add column reclamado_en timestamptz;
alter table public.envios_automatizacion drop constraint envios_automatizacion_estado_check;
alter table public.envios_automatizacion
  add constraint envios_automatizacion_estado_check
  check (estado in ('pendiente', 'enviando', 'enviado', 'simulado', 'error'));
drop index public.envios_pendientes_idx;
create index envios_pendientes_idx on public.envios_automatizacion (created_at)
  where estado in ('pendiente', 'error', 'enviando');
