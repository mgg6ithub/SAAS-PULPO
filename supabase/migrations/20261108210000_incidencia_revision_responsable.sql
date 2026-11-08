create or replace function public.crear_incidencia(
  p_id uuid, p_activo uuid, p_descripcion text, p_gravedad smallint, p_categoria text default '',
  p_fotos text[] default '{}'
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  u uuid := (select auth.uid());
  a public.activos;
  empresa text;
  quien text;
  maquina text;
  ot uuid := null;
  descripcion text := btrim(coalesce(p_descripcion, ''));
  categoria text := btrim(coalesce(p_categoria, ''));
begin
  select * into a from public.activos where id = p_activo;
  if not found or not private.es_miembro(a.empresa_id)
     or (select e.marca from public.empresas e where e.id = a.empresa_id) <> 'industrial' then
    raise exception 'Activo no encontrado' using errcode = '42501';
  end if;
  if p_gravedad not between 0 and 2 then
    raise exception 'Gravedad no válida' using errcode = '22023';
  end if;
  if descripcion = '' then
    raise exception 'Falta la descripción' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_fotos) f where f not like a.empresa_id || '/incidencias/' || p_id || '/%') then
    raise exception 'Fotos fuera de su carpeta' using errcode = '22023';
  end if;

  insert into public.incidencias (id, empresa_id, activo_id, trabajo_id, descripcion, gravedad, estado, fotos, creada_por)
  values (p_id, a.empresa_id, a.id, ot, descripcion, p_gravedad, 0, p_fotos, u);

  select btrim(e.nombre) into empresa from public.empresas e where e.id = a.empresa_id;
  select coalesce(nullif(btrim(w.nombre || ' ' || w.apellidos), ''), us.email) into quien
    from auth.users us
    left join public.miembros m on m.usuario_id = us.id and m.empresa_id = a.empresa_id
    left join public.trabajadores w on w.id = m.trabajador_id
    where us.id = u;
  select concat_ws(' › ', nullif(btrim(concat_ws(' · ', nullif(r.tag, ''), nullif(r.nombre, ''))), ''),
                   case when r.id <> a.id then nullif(btrim(concat_ws(' · ', nullif(a.tag, ''), nullif(a.nombre, ''))), '') end)
    into maquina
    from public.activos r
    where r.id = coalesce((with recursive arriba as (
        select x.id, x.padre_id from public.activos x where x.id = a.id
        union all select x.id, x.padre_id from public.activos x join arriba on x.id = arriba.padre_id)
      select id from arriba where padre_id is null limit 1), a.id);

  insert into public.envios_automatizacion
    (empresa_id, incidencia_id, trabajo_id, ocurrencia, destinatario, asunto, cuerpo, remitente, responder_a)
  select a.empresa_id, p_id, ot, 'incidencia:' || p_id, lower(btrim(us.email)),
    'Nueva incidencia ' || (array['leve', 'media', 'grave'])[p_gravedad + 1] || ' · ' || coalesce(maquina, 'activo'),
    concat_ws(E'\n\n',
      coalesce(quien, 'Un técnico') || ' ha avisado de una incidencia ' || (array['leve', 'media', 'grave'])[p_gravedad + 1]
        || ' en ' || coalesce(maquina, 'un activo') || '.',
      descripcion,
      'Categoría: ' || nullif(categoria, ''),
      case when cardinality(p_fotos) > 0 then 'Con ' || cardinality(p_fotos) || ' foto(s): míralas en Pultec.' end,
      'La incidencia está pendiente de revisión. El responsable decidirá si crea una orden de trabajo.')
      || E'\n\n—\n' || concat_ws(' · ', 'Enviado por Pultec', nullif(empresa, '')),
    case when coalesce(empresa, '') = '' then 'Pultec' else 'Pultec · ' || empresa end,
    (select x.email from auth.users x where x.id = u)
  from public.miembros m join auth.users us on us.id = m.usuario_id
  where m.empresa_id = a.empresa_id and m.rol = 'admin' and us.email like '%_@_%.__%'
  on conflict do nothing;
  return p_id;
end
$$;
revoke execute on function public.crear_incidencia(uuid, uuid, text, smallint, text, text[]) from public, anon;
grant execute on function public.crear_incidencia(uuid, uuid, text, smallint, text, text[]) to authenticated;
comment on function public.crear_incidencia(uuid, uuid, text, smallint, text, text[]) is
  'Pultec: el técnico avisa de una avería: incidencia abierta sin generar OT y correo a los administradores.';

