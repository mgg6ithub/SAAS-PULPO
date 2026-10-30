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
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);
do $$
begin
  begin
    perform public.tomar_ot('00000000-0000-4000-8000-000000000501');
    raise exception 'La cuenta administradora no debe hacerse pasar por un técnico';
  exception when insufficient_privilege then null;
  end;
  insert into public.trabajo_trabajadores(trabajo_id, trabajador_id, empresa_id) values
    ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000201');
  update public.trabajos set estado = 1 where id = '00000000-0000-4000-8000-000000000501';
  assert (select estado = 1 from public.trabajos where id = '00000000-0000-4000-8000-000000000501'), 'Administrador inicia la OT asignada';
  assert (select trabajador_id = '00000000-0000-4000-8000-000000000301' from public.trabajo_trabajadores where trabajo_id = '00000000-0000-4000-8000-000000000501'), 'Conserva el técnico asignado';
  update public.trabajos set estado = 1 where id = '00000000-0000-4000-8000-000000000503';
  assert not found, 'Administrador no modifica otra empresa';
end $$;
rollback;
select 'PRUEBA_OK: vista previa de administrador, asignación conservada y aislamiento de empresas' as resultado;
