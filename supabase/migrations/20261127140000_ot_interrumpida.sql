-- OT interrumpida (estado 4): solo la oficina, al responder una incidencia grave avisada desde una OT, la cierra así
-- y crea la OT correctiva que sigue. Cuenta como cerrada (las funciones usan estado in (0, 1) para las abiertas).
alter table public.trabajos drop constraint if exists trabajos_estado_check;
alter table public.trabajos add constraint trabajos_estado_check check (estado between 0 and 4);
comment on column public.trabajos.estado is '0 pendiente, 1 en curso, 2 completada, 3 cancelada, 4 interrumpida por una incidencia.';
