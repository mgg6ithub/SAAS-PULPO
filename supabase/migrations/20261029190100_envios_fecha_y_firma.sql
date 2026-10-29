-- Emails de las automatizaciones que Gmail mandaba a spam: la fecha salía «—» en las reglas «al completarse»
-- (el trabajo puntual ya no tiene próxima fecha al marcarlo hecho: se usa el día hecho) y el pie era una línea
-- de datos sueltos con «·». Ahora el pie es una firma normal: empresa, a quién llega la respuesta y «Enviado con Pultec».
create or replace function private.encolar_envios(p_automatizacion uuid, p_trabajo uuid, p_ocurrencia text, p_solo uuid default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  with datos as (
    select a.id as auto_id, a.empresa_id, t.id as trabajo_id, a.a_trabajadores, a.a_cliente, a.extras, t.cliente_id,
      coalesce(c.nombre, '') as cliente,
      coalesce(to_char(case when p_ocurrencia like 'hecho:%' then substr(p_ocurrencia, 7)::date else t.proximo end,
        'DD/MM/YYYY'), 'fecha por confirmar') as fecha,
      (select coalesce(string_agg(btrim(w.nombre || ' ' || w.apellidos), ', '), '')
         from public.trabajo_trabajadores tt join public.trabajadores w on w.id = tt.trabajador_id
         where tt.trabajo_id = t.id) as trabajadores,
      t.nombre as trabajo, a.asunto, a.cuerpo,
      btrim(e.nombre) as empresa,
      u.email as admin_email,
      coalesce(nullif(btrim(p.nombre), ''), u.email) as admin
    from public.automatizaciones a
    join public.trabajos t on t.id = p_trabajo and t.empresa_id = a.empresa_id
    join public.empresas e on e.id = a.empresa_id
    left join public.clientes c on c.id = t.cliente_id
    left join auth.users u on u.id = a.creada_por
    left join public.perfiles p on p.usuario_id = a.creada_por
    where a.id = p_automatizacion and a.activa
  ),
  para as (
    select d.auto_id, lower(btrim(w.email)) as correo
    from datos d
    join public.trabajo_trabajadores tt on tt.trabajo_id = d.trabajo_id and d.a_trabajadores
    join public.trabajadores w on w.id = tt.trabajador_id and w.activo
    where (p_solo is null or w.id = p_solo)
    union
    select d.auto_id, lower(btrim(c.email)) from datos d join public.clientes c on c.id = d.cliente_id where d.a_cliente
    union
    select d.auto_id, lower(btrim(x)) from datos d, unnest(d.extras) x
  )
  insert into public.envios_automatizacion
    (empresa_id, automatizacion_id, trabajo_id, ocurrencia, destinatario, asunto, cuerpo, remitente, responder_a)
  select d.empresa_id, d.auto_id, d.trabajo_id, p_ocurrencia, p.correo,
    replace(replace(replace(replace(d.asunto, '{trabajo}', d.trabajo), '{cliente}', d.cliente), '{fecha}', d.fecha),
      '{trabajadores}', d.trabajadores),
    replace(replace(replace(replace(d.cuerpo, '{trabajo}', d.trabajo), '{cliente}', d.cliente), '{fecha}', d.fecha),
      '{trabajadores}', d.trabajadores)
      || E'\n\n-- \n' || concat_ws(E'\n', coalesce(nullif(d.empresa, ''), 'Pultec'),
        'Para cualquier duda, responde a este correo' || coalesce(' y le llegará a ' || d.admin, '') || '.',
        'Enviado con Pultec'),
    case when d.empresa = '' then 'Pultec' else 'Pultec · ' || d.empresa end,
    d.admin_email
  from datos d join para p on p.auto_id = d.auto_id
  where p.correo like '%_@_%.__%'
  on conflict do nothing;
  get diagnostics n = row_count;
  return n;
end
$$;
revoke execute on function private.encolar_envios(uuid, uuid, text, uuid) from public, anon, authenticated;
