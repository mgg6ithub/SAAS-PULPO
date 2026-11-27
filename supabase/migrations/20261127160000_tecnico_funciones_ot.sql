-- El límite de lo que un técnico cambia en una OT es para sus escrituras directas. Las funciones que ya validan
-- (marcar_checklist, tomar_ot, pausar_ot; security definer, corren como su dueño) quedaban bloqueadas: un técnico
-- no podía marcar la checklist, empezar ni pausar.
create or replace function private.limitar_cambios_trabajador() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is null or private.es_admin(new.empresa_id) or current_user <> 'authenticated' then
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
