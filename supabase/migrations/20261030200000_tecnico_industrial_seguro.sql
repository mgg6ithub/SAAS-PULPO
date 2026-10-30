-- IPT-012: correcciones de la migración ya aplicada, sin reescribir su historial.
drop policy trabajos_select_tecnico on public.trabajos;
alter policy trabajos_select on public.trabajos
  using (private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id)
    or (tipo_mantenimiento is not null and private.ot_libre_de_mi_categoria(id)));

-- ── Empezar una OT: el técnico se la asigna ─────────────────────────────────
create or replace function private.tomar_ot(p_trabajo uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.trabajos; w uuid;
begin
  select * into t from public.trabajos where id = p_trabajo for update;
  if not found then
    raise exception 'OT no encontrada' using errcode = 'P0001';
  end if;
  w := private.mi_trabajador(t.empresa_id);
  if w is null then
    raise exception 'Solo un técnico puede tomar una OT' using errcode = '42501';
  end if;
  if (select e.marca from public.empresas e where e.id = t.empresa_id) <> 'industrial'
     or not t.activa or t.plantilla or t.tipo_mantenimiento is null or t.estado not in (0, 1) then
    raise exception 'Esta OT ya no está pendiente' using errcode = '42501';
  end if;
  if exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = t.id and tt.trabajador_id = w) then
    update public.trabajos set estado = 1 where id = t.id;
    return;
  end if;
  if not private.ot_libre_de_mi_categoria(t.id) then
    raise exception 'Esta OT ya no está libre o no es de tu categoría' using errcode = '42501';
  end if;
  insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (t.id, w, t.empresa_id);
  update public.trabajos set estado = 1 where id = t.id;
end
$$;
revoke execute on function private.tomar_ot(uuid) from public, anon;
grant execute on function private.tomar_ot(uuid) to authenticated;
comment on function private.tomar_ot(uuid) is 'Comprueba y bloquea la OT industrial antes de asignarla al técnico e iniciarla.';
create or replace function public.tomar_ot(p_trabajo uuid) returns void
language sql security invoker set search_path = '' as $$ select private.tomar_ot(p_trabajo) $$;
revoke execute on function public.tomar_ot(uuid) from public, anon;
grant execute on function public.tomar_ot(uuid) to authenticated;
comment on function public.tomar_ot(uuid) is 'iPultec: el técnico se asigna una OT libre de su categoría al empezarla.';

create or replace function private.crear_incidencia(
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
  ot uuid := gen_random_uuid();
  descripcion text := btrim(coalesce(p_descripcion, ''));
  categoria text := btrim(coalesce(p_categoria, ''));
begin
  select * into a from public.activos where id = p_activo;
  if not found or not private.es_miembro(a.empresa_id)
     or (select e.marca from public.empresas e where e.id = a.empresa_id) <> 'industrial' then
    raise exception 'Activo no encontrado' using errcode = '42501';
  end if;
  if p_gravedad is null or p_gravedad not between 0 and 2 then
    raise exception 'Gravedad no válida' using errcode = '22023';
  end if;
  if descripcion = '' then
    raise exception 'Falta la descripción' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_fotos) f where f not like a.empresa_id || '/incidencias/' || p_id || '/%') then
    raise exception 'Fotos fuera de su carpeta' using errcode = '22023';
  end if;

  insert into public.trabajos (id, empresa_id, nombre, notas, tipo_mantenimiento, activo_id, competencias, proximo,
                               periodicidad, criticidad, plantilla)
  values (ot, a.empresa_id, left(descripcion, 120), descripcion, case when p_gravedad = 2 then 2 else 1 end, a.id,
          case when categoria = '' then '{}'::text[] else array[categoria] end, current_date, 5, 3, false);
  insert into public.incidencias (id, empresa_id, activo_id, trabajo_id, descripcion, gravedad, estado, fotos, creada_por)
  values (p_id, a.empresa_id, a.id, ot, descripcion, p_gravedad, 1, p_fotos, u);

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
      case when cardinality(p_fotos) > 0 then 'Con ' || cardinality(p_fotos) || ' foto(s): míralas en iPultec.' end,
      'Se ha creado una OT ' || case when p_gravedad = 2 then 'de correctivo crítico' else 'de correctivo no crítico' end
        || ' en el activo; aparece en Mantenimientos → Incidencias.')
      || E'\n\n-- \n' || concat_ws(' · ', 'Enviado por iPultec', nullif(empresa, '')),
    case when coalesce(empresa, '') = '' then 'iPultec' else 'iPultec · ' || empresa end,
    (select x.email from auth.users x where x.id = u)
  from public.miembros m join auth.users us on us.id = m.usuario_id
  where m.empresa_id = a.empresa_id and m.rol = 'admin' and us.email like '%_@_%.__%'
  on conflict do nothing;
  return p_id;
end
$$;
revoke execute on function private.crear_incidencia(uuid, uuid, text, smallint, text, text[]) from public, anon;
grant execute on function private.crear_incidencia(uuid, uuid, text, smallint, text, text[]) to authenticated;
comment on function private.crear_incidencia(uuid, uuid, text, smallint, text, text[]) is
  'Comprueba la pertenencia industrial y crea la incidencia, su OT y los avisos en una transacción.';
create or replace function public.crear_incidencia(
  p_id uuid, p_activo uuid, p_descripcion text, p_gravedad smallint, p_categoria text default '',
  p_fotos text[] default '{}'
) returns uuid language sql security invoker set search_path = '' as $$
  select private.crear_incidencia(p_id, p_activo, p_descripcion, p_gravedad, p_categoria, p_fotos)
$$;
revoke execute on function public.crear_incidencia(uuid, uuid, text, smallint, text, text[]) from public, anon;
grant execute on function public.crear_incidencia(uuid, uuid, text, smallint, text, text[]) to authenticated;
comment on function public.crear_incidencia(uuid, uuid, text, smallint, text, text[]) is
  'iPultec: el técnico avisa de una avería: incidencia + OT correctiva en el activo y correo a los administradores.';

create policy fotos_incidencias_delete on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[2] = 'incidencias'
         and private.es_miembro_industrial(((storage.foldername(name))[1])::uuid)
         and owner_id = (select auth.uid())::text);
revoke execute on function private.ot_libre_de_mi_categoria(uuid), private.es_miembro_industrial(uuid) from public, anon;
grant execute on function private.ot_libre_de_mi_categoria(uuid), private.es_miembro_industrial(uuid) to authenticated;
comment on function private.es_miembro_industrial(uuid) is 'Comprueba que la cuenta pertenece a la empresa industrial.';
