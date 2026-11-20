-- Pultec: en activos planificados por turnos, el aviso previo cuenta días de trabajo (los que tienen turnos en
-- «Uso de las máquinas»), no días de calendario: «avisar 10 días antes» = 10 jornadas previstas antes.
-- Sin planificación (uso fijo), sigue contando días naturales.
create or replace function private.dias_hasta_aviso(a public.activos, cuando date) returns integer
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := coalesce(private.raiz(a.id), a);
  n integer := 0;
begin
  if cuando is null then return null; end if;
  if not r.uso_planificado then return cuando - current_date; end if;
  select count(*) into n
  from generate_series(current_date + 1, cuando, interval '1 day') d
  where coalesce((r.turnos ->> to_char(d, 'YYYY-MM-DD'))::numeric, 0) > 0;
  return n;
end $$;

create or replace function private.encolar_avisos_planes() returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  with listos as (
    select p.*, a.empresa_id as emp, a.tag, a.nombre as activo, private.fecha_prevista(p, a) as cuando,
      private.dias_hasta_aviso(a, private.fecha_prevista(p, a)) as quedan
    from public.planes_mantenimiento p
    join public.activos a on a.id = p.activo_id
    where p.activa and p.aviso_dias is not null
  ),
  para as (
    select l.*, lower(btrim(c)) as correo
    from listos l, unnest(string_to_array(l.aviso_correos, ',')) c
    where l.aviso_correos <> '' and btrim(c) like '%@%'
    union
    select l.*, lower(coalesce(pf.correo, u.email)) as correo
    from listos l
    join public.miembros m on m.empresa_id = l.emp and m.rol = 'admin'
    join auth.users u on u.id = m.usuario_id
    left join public.perfiles pf on pf.usuario_id = m.usuario_id
    where l.aviso_correos = ''
  )
  insert into public.envios_automatizacion (empresa_id, plan_id, ocurrencia, destinatario, asunto, cuerpo)
  select emp, id, 'aviso:' || coalesce(ultimo::text, 'inicio'), correo,
    'Preparar mantenimiento: ' || nombre || ' · ' || coalesce(nullif(tag, ''), activo),
    concat_ws(e'\n\n',
      'Hola:',
      'El mantenimiento «' || nombre || '» de ' || concat_ws(' · ', nullif(tag, ''), nullif(activo, ''))
        || ' está previsto para el ' || to_char(cuando, 'DD/MM/YYYY') || '.',
      nullif('Hay que preparar: ' || nullif(preparar, ''), ''),
      case when subcontratado then 'Lo hace una empresa externa: ' || coalesce(nullif(empresa_externa, ''), 'sin indicar') || '.' end,
      e'-- \nPultec')
  from para
  where cuando is not null and quedan <= aviso_dias
  on conflict (plan_id, ocurrencia, destinatario) where plan_id is not null do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function private.dias_hasta_aviso(public.activos, date), private.encolar_avisos_planes()
  from public, anon, authenticated;
