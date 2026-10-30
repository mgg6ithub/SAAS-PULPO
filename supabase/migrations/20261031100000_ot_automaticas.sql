-- iPultec IPT-019 a 022: OT automáticas a partir de los mantenimientos.
--   · trabajos.plan_id: de qué mantenimiento sale la OT; trabajos.ejecutado_por: quién la cerró.
--   · Al cerrar (estado realizado) una OT con plan, el mantenimiento vuelve a cero: guarda fecha y contador.
--   · private.generar_ots(): crea la OT de cada mantenimiento vencido (por horas o fecha) sin OT pendiente.
--   · Alerta previa: X días antes de la fecha prevista, un correo a los responsables por la cola de envíos.

-- ── Columnas ─────────────────────────────────────────────────────────────────
alter table public.trabajos
  add column if not exists plan_id uuid references public.planes_mantenimiento (id) on delete set null,
  add column if not exists ejecutado_por uuid references public.trabajadores (id) on delete set null;
create index if not exists trabajos_plan_id_idx on public.trabajos (plan_id);
create index if not exists trabajos_ejecutado_por_idx on public.trabajos (ejecutado_por);

alter table public.planes_mantenimiento
  add column if not exists aviso_dias integer check (aviso_dias is null or aviso_dias between 1 and 365),
  add column if not exists aviso_correos text not null default '',
  add column if not exists preparar text not null default '',
  add column if not exists subcontratado boolean not null default false,
  add column if not exists empresa_externa text not null default '';

-- La cola de correos también lleva avisos de mantenimientos, que no tienen trabajo ni automatización.
alter table public.envios_automatizacion
  alter column trabajo_id drop not null,
  add column if not exists plan_id uuid references public.planes_mantenimiento (id) on delete cascade;
create unique index if not exists envios_plan_unico on public.envios_automatizacion (plan_id, ocurrencia, destinatario)
  where plan_id is not null;
create index if not exists envios_plan_id_idx on public.envios_automatizacion (plan_id);

-- ── Contador estimado y fecha prevista ──────────────────────────────────────
-- Horas del activo hoy: la última lectura más el ritmo de uso desde entonces.
create or replace function private.horas_hoy(a public.activos) returns numeric
language sql stable set search_path = '' as $$
  select coalesce(a.horas, 0)
    + coalesce(case when a.uso_semanal then a.uso_horas / 7 else a.uso_horas end, 0)
      * greatest(0, current_date - coalesce(a.lectura_fecha, current_date))
$$;

-- Cuándo toca: la fecha puesta o, por horas, la estimada con el ritmo de uso (null si no se puede estimar).
create or replace function private.fecha_prevista(p public.planes_mantenimiento, a public.activos) returns date
language plpgsql stable set search_path = '' as $$
declare
  uso numeric := coalesce(case when a.uso_semanal then a.uso_horas / 7 else a.uso_horas end, 0);
  quedan numeric;
begin
  if p.proximo is not null or p.cada_horas is null then return p.proximo; end if;
  quedan := p.cada_horas - (private.horas_hoy(a) - coalesce(p.ultimo_horas, 0));
  if quedan <= 0 then return current_date; end if;
  if uso <= 0 then return null; end if;
  return current_date + ceil(quedan / uso)::integer;
end $$;

-- ── Generar las OT vencidas ─────────────────────────────────────────────────
create or replace function private.generar_ots() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  nueva uuid;
  tecnico uuid;
  n integer := 0;
begin
  for r in
    select p.*, a.empresa_id as emp
    from public.planes_mantenimiento p
    join public.activos a on a.id = p.activo_id
    where p.activa
      and (
        (p.proximo is not null and p.proximo <= current_date)
        or (p.cada_horas is not null and private.horas_hoy(a) - coalesce(p.ultimo_horas, 0) >= p.cada_horas)
      )
      and not exists (
        select 1 from public.trabajos t
        where t.plan_id = p.id and t.activa and t.estado in (0, 1)
      )
  loop
    nueva := gen_random_uuid();
    insert into public.trabajos (
      id, empresa_id, activo_id, plan_id, nombre, plantilla, proximo, periodicidad, criticidad,
      duracion_min, estado, activa, competencias, tipo_mantenimiento, notas
    ) values (
      nueva, r.emp, r.activo_id, r.id,
      r.nombre || case when r.subcontratado then ' (subcontratado)' else '' end,
      false, current_date, 5, 3, r.duracion_min, 0, true,
      case when r.categoria <> '' and not r.subcontratado then array[r.categoria] else array[]::text[] end,
      r.tipo_mantenimiento,
      concat_ws(e'\n\n',
        nullif(case when r.subcontratado then 'Lo hace una empresa externa: ' || nullif(r.empresa_externa, '') end, ''),
        nullif(r.procedimiento, ''),
        nullif('Repuestos: ' || nullif(r.repuestos, ''), ''),
        nullif('Preparar: ' || nullif(r.preparar, ''), ''))
    );
    -- Si de su categoría solo hay un técnico activo, se le asigna directamente.
    if not r.subcontratado and r.categoria <> '' then
      select min(w.id::text)::uuid into tecnico
      from public.trabajadores w
      where w.empresa_id = r.emp and w.activo and r.categoria = any (w.competencias)
      having count(*) = 1;
      if tecnico is not null then
        insert into public.trabajo_trabajadores (trabajo_id, trabajador_id, empresa_id) values (nueva, tecnico, r.emp);
      end if;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ── Cerrar la OT reinicia su mantenimiento ──────────────────────────────────
create or replace function private.al_cerrar_ot() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  a public.activos;
  p public.planes_mantenimiento;
begin
  if new.estado = 2 and old.estado is distinct from 2 then
    -- Quién la cierra: el técnico de la cuenta; si es un administrador, el primer técnico asignado.
    new.ejecutado_por := coalesce(
      new.ejecutado_por,
      (select m.trabajador_id from public.miembros m
        where m.usuario_id = (select auth.uid()) and m.empresa_id = new.empresa_id and m.trabajador_id is not null
        limit 1),
      (select tt.trabajador_id from public.trabajo_trabajadores tt where tt.trabajo_id = new.id limit 1));
    if new.plan_id is not null then
      select * into p from public.planes_mantenimiento where id = new.plan_id;
      select * into a from public.activos where id = p.activo_id;
      update public.planes_mantenimiento set
        ultimo = current_date,
        ultimo_horas = private.horas_hoy(a),
        proximo = case when p.cada_dias is not null then current_date + p.cada_dias end
      where id = p.id;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trabajos_al_cerrar_ot on public.trabajos;
create trigger trabajos_al_cerrar_ot before update of estado on public.trabajos
  for each row execute function private.al_cerrar_ot();

-- ── Alerta previa ───────────────────────────────────────────────────────────
-- Un correo por mantenimiento y ciclo (el ciclo es la fecha del último hecho), a los correos del mantenimiento
-- o, si no hay, a los administradores de la empresa.
create or replace function private.encolar_avisos_planes() returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  with listos as (
    select p.*, a.empresa_id as emp, a.tag, a.nombre as activo, private.fecha_prevista(p, a) as cuando
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
      e'-- \niPultec')
  from para
  where cuando is not null and cuando - aviso_dias <= current_date
  on conflict (plan_id, ocurrencia, destinatario) where plan_id is not null do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- ── Cada hora ───────────────────────────────────────────────────────────────
select cron.schedule('ipultec-mantenimientos', '7 * * * *', $cron$
  select private.generar_ots();
  select private.encolar_avisos_planes();
$cron$);

revoke all on function private.generar_ots(), private.encolar_avisos_planes(), private.al_cerrar_ot() from public, anon, authenticated;
