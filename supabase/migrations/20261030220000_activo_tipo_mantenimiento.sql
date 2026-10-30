-- iPultec: el estado de mantenimiento es del activo, no de la OT.
alter table public.activos
  add column mantenimiento_tipo smallint not null default 0 check (mantenimiento_tipo between 0 and 2);
comment on column public.activos.mantenimiento_tipo is '0 preventivo; 1 correctivo no crítico; 2 correctivo crítico.';
