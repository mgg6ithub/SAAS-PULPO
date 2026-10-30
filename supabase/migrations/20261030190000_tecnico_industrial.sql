-- iPultec (IPT-012): vista del técnico. Solo afecta a empresas con marca industrial; Pultec queda igual.
--   · El técnico ve también las OT sin asignar de su categoría y se las asigna al empezarlas (tomar_ot).
--   · Nueva incidencia (crear_incidencia): incidencia + OT correctiva en el activo, enlazadas, y un correo a
--     cada administrador por la cola de envíos de siempre (la manda la Edge Function enviar-automatizaciones).
--   · Fotos de incidencias en <empresa>/incidencias/<incidencia>/ del bucket fotos.

-- ── OT libre de mi categoría ────────────────────────────────────────────────
create function private.ot_libre_de_mi_categoria(p_trabajo uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.trabajos t
    join public.empresas e on e.id = t.empresa_id and e.marca = 'industrial'
    join public.trabajadores w on w.id = private.mi_trabajador(t.empresa_id) and w.activo
    where t.id = p_trabajo and t.activa and not t.plantilla and t.tipo_mantenimiento is not null
      and t.estado in (0, 1)
      and not exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = t.id)
      and t.competencias <@ w.competencias
  )
$$;
comment on function private.ot_libre_de_mi_categoria(uuid) is
  'iPultec: OT activa, sin terminar y sin técnico, cuya categoría tiene el técnico de la cuenta.';

create policy trabajos_select_tecnico on public.trabajos for select to authenticated
  using (tipo_mantenimiento is not null and private.ot_libre_de_mi_categoria(id));

-- ── Empezar una OT: el técnico se la asigna ─────────────────────────────────
create function public.tomar_ot(p_trabajo uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.trabajos; w uuid;
begin
  select * into t from public.trabajos where id = p_trabajo;
  if not found then
    raise exception 'OT no encontrada' using errcode = 'P0001';
  end if;
  w := private.mi_trabajador(t.empresa_id);
  if w is null then
    raise exception 'Solo un técnico puede tomar una OT' using errcode = '42501';
  end if;
  if exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = t.id and tt.trabajador_id = w) then
    return;
  end if;
  if not private.ot_libre_de_mi_categoria(t.id) then
    raise exception 'Esta OT ya no está libre o no es de tu categoría' using errcode = '42501';
  end if;
  insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (t.id, w, t.empresa_id);
end
$$;
revoke execute on function public.tomar_ot(uuid) from public, anon;
grant execute on function public.tomar_ot(uuid) to authenticated;
comment on function public.tomar_ot(uuid) is 'iPultec: el técnico se asigna una OT libre de su categoría al empezarla.';

-- ── Correos de incidencias por la cola de envíos ────────────────────────────
alter table public.envios_automatizacion
  alter column automatizacion_id drop not null,
  add column incidencia_id uuid references public.incidencias (id) on delete cascade;
create index envios_incidencia_id_idx on public.envios_automatizacion (incidencia_id);
create unique index envios_incidencia_unico on public.envios_automatizacion (incidencia_id, destinatario)
  where incidencia_id is not null;
comment on column public.envios_automatizacion.incidencia_id is
  'iPultec: aviso de una incidencia al responsable (sin automatización).';

-- ── Nueva incidencia: incidencia + OT + aviso ───────────────────────────────
-- p_id lo genera la app para subir antes las fotos a su carpeta. Gravedad 0 leve, 1 media, 2 grave: la OT es
-- correctivo crítico (2) si es grave y no crítico (1) si no. p_categoria: la de los técnicos que pueden hacerla.
create function public.crear_incidencia(
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
  if p_gravedad not between 0 and 2 then
    raise exception 'Gravedad no válida' using errcode = '22023';
  end if;
  if descripcion = '' then
    raise exception 'Falta la descripción' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_fotos) f where f not like a.empresa_id || '/incidencias/' || p_id || '/%') then
    raise exception 'Fotos fuera de su carpeta' using errcode = '22023';
  end if;

  insert into public.trabajos (id, empresa_id, nombre, notas, tipo_mantenimiento, activo_id, competencias, proximo,
                               periodicidad, criticidad)
  values (ot, a.empresa_id, left(descripcion, 120), descripcion, case when p_gravedad = 2 then 2 else 1 end, a.id,
          case when categoria = '' then '{}'::text[] else array[categoria] end, current_date, 5, 3);
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
      || E'\n\n—\n' || concat_ws(' · ', 'Enviado por iPultec', nullif(empresa, '')),
    case when coalesce(empresa, '') = '' then 'iPultec' else 'iPultec · ' || empresa end,
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
  'iPultec: el técnico avisa de una avería: incidencia + OT correctiva en el activo y correo a los administradores.';

-- ── Fotos de incidencias ────────────────────────────────────────────────────
create function private.es_miembro_industrial(p_empresa uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.es_miembro(p_empresa)
    and exists (select 1 from public.empresas e where e.id = p_empresa and e.marca = 'industrial')
$$;
create policy fotos_incidencias_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[2] = 'incidencias'
              and private.es_miembro_industrial(((storage.foldername(name))[1])::uuid));
create policy fotos_incidencias_select on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[2] = 'incidencias'
         and private.es_miembro_industrial(((storage.foldername(name))[1])::uuid)
         and (private.es_admin(((storage.foldername(name))[1])::uuid) or owner_id = (select auth.uid())::text));
