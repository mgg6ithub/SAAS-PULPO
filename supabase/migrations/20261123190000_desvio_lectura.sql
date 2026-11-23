-- Desvío de la lectura: horas reales menos las estimadas con los turnos al apuntar la última lectura del
-- contador. En «Uso de activos» avisa cuando el patrón no refleja el uso real. La app lo calcula igual
-- (`horasHoy` en lib/industrial/planes.dart).

alter table public.activos add column if not exists desvio numeric;

create or replace function public.apuntar_contador(p_activo uuid, p_horas numeric)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.activos;
begin
  select * into a from public.activos where id = p_activo;
  if a.id is null or (private.mi_trabajador(a.empresa_id) is null and not private.es_admin(a.empresa_id)) then
    raise exception 'Sin acceso a ese activo' using errcode = '42501';
  end if;
  if p_horas is null or p_horas < 0 or p_horas > 1000000 then
    raise exception 'Lectura no válida' using errcode = '22023';
  end if;
  update public.activos
    set horas = p_horas,
        lectura_fecha = current_date,
        desvio = case when a.uso_planificado then p_horas - private.horas_hoy(a) else desvio end
    where id = p_activo;
end;
$$;

revoke execute on function public.apuntar_contador(uuid, numeric) from public, anon;
grant execute on function public.apuntar_contador(uuid, numeric) to authenticated;
