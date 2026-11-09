-- Pultec: toda OT sin hora entra a las 8:00 (se cambia luego en el calendario). También las que crea la base.
create or replace function private.ot_hora_por_defecto() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.tipo_mantenimiento is not null and new.inicio_min is null
     and new.ventana_desde_min is null and new.ventana_hasta_min is null then
    new.inicio_min := 480;
  end if;
  return new;
end $$;

drop trigger if exists trabajos_hora_por_defecto on public.trabajos;
create trigger trabajos_hora_por_defecto before insert on public.trabajos
  for each row execute function private.ot_hora_por_defecto();

revoke all on function private.ot_hora_por_defecto() from public, anon, authenticated;

-- Las pendientes de Pultec que hoy no tienen hora, a las 8:00.
update public.trabajos set inicio_min = 480
where tipo_mantenimiento is not null and inicio_min is null and activa and estado in (0, 1)
  and ventana_desde_min is null and ventana_hasta_min is null;

-- Las pendientes de Pultec creadas sin día (cuando se podía) pasan a hoy: la columna «Sin fecha» está aparcada.
update public.trabajos set proximo = current_date
where tipo_mantenimiento is not null and proximo is null and activa and estado in (0, 1) and not plantilla;
