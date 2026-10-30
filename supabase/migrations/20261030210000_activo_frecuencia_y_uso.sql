-- Intervalo y ritmo propios de cada activo o componente. Sin cambios en Pultec residencial.
alter table public.activos
  add column mantenimiento_modo smallint not null default 0 check (mantenimiento_modo between 0 and 3),
  add column mantenimiento_cada_horas numeric(12, 1) check (mantenimiento_cada_horas > 0),
  add column mantenimiento_cada_meses integer check (mantenimiento_cada_meses between 1 and 1200),
  add column mantenimiento_fecha date,
  add column mantenimiento_ultimo date,
  add column mantenimiento_ultimo_horas numeric(12, 1) not null default 0 check (mantenimiento_ultimo_horas >= 0),
  add column uso_horas numeric(8, 2) not null default 0 check (uso_horas >= 0),
  add column uso_semanal boolean not null default false,
  add column lectura_fecha date not null default current_date,
  add constraint activo_lectura_ultimo check (mantenimiento_ultimo_horas <= horas),
  add constraint activo_uso_limite check (uso_horas <= case when uso_semanal then 168 else 24 end),
  add constraint activo_intervalo_definido check (
    mantenimiento_modo = 0
    or (mantenimiento_modo = 1 and mantenimiento_cada_horas is not null)
    or (mantenimiento_modo = 2 and mantenimiento_cada_meses is not null)
    or (mantenimiento_modo = 3 and mantenimiento_fecha is not null));
comment on column public.activos.mantenimiento_modo is '0 sin definir; 1 horas de uso; 2 meses naturales; 3 fecha concreta. Independiente del padre.';
comment on column public.activos.mantenimiento_cada_horas is 'Horas de funcionamiento entre mantenimientos de este activo o componente.';
comment on column public.activos.mantenimiento_cada_meses is 'Meses naturales entre mantenimientos, contados desde el último.';
comment on column public.activos.mantenimiento_fecha is 'Próxima fecha concreta, cuando el modo es fecha.';
comment on column public.activos.mantenimiento_ultimo is 'Fecha del último mantenimiento; referencia para intervalos de meses.';
comment on column public.activos.mantenimiento_ultimo_horas is 'Lectura real del contador en el último mantenimiento.';
comment on column public.activos.uso_horas is 'Media de uso por día natural o total semanal; solo para estimar la próxima fecha.';
comment on column public.activos.uso_semanal is 'True: uso_horas representa el total semanal; false: media por día natural.';
comment on column public.activos.lectura_fecha is 'Fecha de la lectura real de horas. Las estimaciones no cambian esta lectura.';
