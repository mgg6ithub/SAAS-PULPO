-- Al cerrar una OT, el técnico guarda también el resultado de su parte (completada, con incidencias o sin hacer)
-- y el estado de la máquina. Antes solo podía tocar estado y fechas y el cierre se rechazaba entero.
-- Dar por resuelta una incidencia sigue siendo cosa del responsable: el técnico solo puede dejarla sin resolver.
create or replace function private.limitar_cambios_trabajador() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is null or private.es_admin(new.empresa_id) then
    return new;
  end if;
  if new.resultado_resuelto and not old.resultado_resuelto then
    raise exception 'El técnico no puede dar por resuelta una incidencia' using errcode = '42501';
  end if;
  if (to_jsonb(new) - 'estado' - 'ultimo' - 'proximo' - 'updated_at' - 'resultado' - 'resultado_resuelto'
       - 'estado_maquina')
     <> (to_jsonb(old) - 'estado' - 'ultimo' - 'proximo' - 'updated_at' - 'resultado' - 'resultado_resuelto'
       - 'estado_maquina') then
    raise exception 'El trabajador solo puede cambiar el estado, las fechas y el resultado del trabajo'
      using errcode = '42501';
  end if;
  return new;
end
$$;
comment on function private.limitar_cambios_trabajador() is
  'Trigger de trabajos: un trabajador solo puede cambiar estado, fechas, resultado (sin resolverlo) y estado de la máquina.';

-- El técnico apunta la lectura del contador al cerrar su parte. No puede editar activos (la app de técnico solo
-- sube sus trabajos), así que va por esta función: solo el contador y la fecha de lectura, de su empresa.
create or replace function public.apuntar_contador(p_activo uuid, p_horas numeric)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  emp uuid;
begin
  select a.empresa_id into emp from public.activos a where a.id = p_activo;
  if emp is null or (private.mi_trabajador(emp) is null and not private.es_admin(emp)) then
    raise exception 'Sin acceso a ese activo' using errcode = '42501';
  end if;
  if p_horas is null or p_horas < 0 or p_horas > 1000000 then
    raise exception 'Lectura no válida' using errcode = '22023';
  end if;
  update public.activos set horas = p_horas, lectura_fecha = current_date where id = p_activo;
end;
$$;

revoke execute on function public.apuntar_contador(uuid, numeric) from public, anon;
grant execute on function public.apuntar_contador(uuid, numeric) to authenticated;
