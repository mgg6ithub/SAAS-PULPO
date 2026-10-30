-- Ejecutar con supabase db query --linked --file supabase/tests/tecnico_industrial.sql.
-- Todo se deshace: no quedan cuentas, datos ni correos pendientes.
begin;
insert into auth.users (id, email) values
 ('00000000-0000-4000-8000-000000000101', 'admin-iptecnico@example.invalid'),
 ('00000000-0000-4000-8000-000000000102', 'tecnico-a@example.invalid'),
 ('00000000-0000-4000-8000-000000000103', 'tecnico-b@example.invalid'),
 ('00000000-0000-4000-8000-000000000104', 'sin-invitacion@example.invalid');
insert into public.empresas (id, nombre, marca, creada_por) values
 ('00000000-0000-4000-8000-000000000201', 'PRUEBA técnico A', 'industrial', '00000000-0000-4000-8000-000000000101'),
 ('00000000-0000-4000-8000-000000000202', 'PRUEBA técnico B', 'industrial', '00000000-0000-4000-8000-000000000101');
insert into public.trabajadores (id, empresa_id, nombre, competencias) values
 ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000201', 'Técnico A', array['Mecánica']),
 ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000201', 'Técnico B', array['Mecánica']);
insert into public.miembros (usuario_id, empresa_id, rol, trabajador_id) values
 ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', 'admin', null),
 ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000201', 'trabajador', '00000000-0000-4000-8000-000000000301'),
 ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000201', 'trabajador', '00000000-0000-4000-8000-000000000302');
insert into public.activos (id, empresa_id, nombre) values
 ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000201', 'Motor A'),
 ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000202', 'Motor ajeno');
insert into public.trabajos (id, empresa_id, nombre, plantilla, tipo_mantenimiento, competencias) values
 ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000201', 'Libre mecánica', false, 0, array['Mecánica']),
 ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000201', 'Libre electricidad', false, 0, array['Electricidad']),
 ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000202', 'Ajena', false, 0, array['Mecánica']);
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000102', true);
do $$
begin
  assert (select count(*) from public.trabajos where id in (
    '00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000502',
    '00000000-0000-4000-8000-000000000503')) = 1, 'OT libres filtradas por empresa y categoría';
  begin
    perform public.tomar_ot('00000000-0000-4000-8000-000000000502');
    raise exception 'Ha tomado una OT de otra categoría';
  exception when insufficient_privilege then null;
  end;
  perform public.tomar_ot('00000000-0000-4000-8000-000000000501');
  perform public.tomar_ot('00000000-0000-4000-8000-000000000501');
  assert (select estado = 1 from public.trabajos where id = '00000000-0000-4000-8000-000000000501'), 'OT en curso';
  assert (select count(*) from public.trabajo_trabajadores where trabajo_id = '00000000-0000-4000-8000-000000000501') = 1, 'Asignación idempotente';
  begin
    perform public.crear_incidencia('00000000-0000-4000-8000-000000000601',
      '00000000-0000-4000-8000-000000000402', 'Ajena', 1::smallint);
    raise exception 'Ha creado una incidencia en otra empresa';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.crear_incidencia('00000000-0000-4000-8000-000000000601',
      '00000000-0000-4000-8000-000000000401', 'Sin gravedad', null::smallint);
    raise exception 'Ha aceptado gravedad nula';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.crear_incidencia('00000000-0000-4000-8000-000000000601',
      '00000000-0000-4000-8000-000000000401', 'Fotos ajenas', 1::smallint, '', array['otra/foto.jpg']);
    raise exception 'Ha aceptado fotos ajenas';
  exception when invalid_parameter_value then null;
  end;
  perform public.crear_incidencia('00000000-0000-4000-8000-000000000601',
    '00000000-0000-4000-8000-000000000401', 'Fuga de aceite', 2::smallint, 'Mecánica');
  assert (select estado = 1 from public.incidencias where id = '00000000-0000-4000-8000-000000000601'), 'Incidencia con OT';
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000103', true);
do $$
begin
  assert not exists (select 1 from public.trabajos where id = '00000000-0000-4000-8000-000000000501'), 'Otro técnico no ve la OT tomada';
  begin
    perform public.tomar_ot('00000000-0000-4000-8000-000000000501');
    raise exception 'Otro técnico ha tomado la misma OT';
  exception when insufficient_privilege then null;
  end;
end $$;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000104', true);
do $$
begin
  begin
    perform public.entrar(null, 'industrial');
    raise exception 'Industrial ha permitido el alta libre';
  exception when sqlstate 'P0003' then null;
  end;
  perform public.entrar(null, 'residencial');
  assert exists (select 1 from public.miembros where usuario_id = auth.uid()), 'Residencial sigue creando empresa';
end $$;
reset role;
do $$
begin
  assert exists (select 1 from public.incidencias i join public.trabajos t on t.id = i.trabajo_id
    where i.id = '00000000-0000-4000-8000-000000000601' and not t.plantilla and t.tipo_mantenimiento = 2
      and t.competencias = array['Mecánica'] and t.activo_id = i.activo_id), 'OT correctiva real en el activo';
  assert (select count(*) from public.envios_automatizacion where incidencia_id = '00000000-0000-4000-8000-000000000601') = 1,
    'Un aviso al administrador';
end $$;
rollback;
select 'PRUEBA_OK: técnico, categoría, aislamiento, incidencias, avisos e invitación' as resultado;
