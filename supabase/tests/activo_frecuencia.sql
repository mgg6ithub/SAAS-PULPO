-- Prueba transaccional: no deja datos ni cuentas.
begin;

insert into auth.users (id, email) values ('00000000-0000-4000-8000-000000000711','prueba-intervalos@example.invalid');
insert into public.empresas (id, nombre, marca) values
 ('00000000-0000-4000-8000-000000000712','PRUEBA intervalos A','industrial'),
 ('00000000-0000-4000-8000-000000000713','PRUEBA intervalos B','industrial');
insert into public.miembros (usuario_id,empresa_id,rol) values
 ('00000000-0000-4000-8000-000000000711','00000000-0000-4000-8000-000000000712','admin');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000711',true);
insert into public.activos (id,empresa_id,nombre,horas,mantenimiento_modo,mantenimiento_cada_horas,uso_horas)
 values ('00000000-0000-4000-8000-000000000714','00000000-0000-4000-8000-000000000712','Camión',1200,1,5000,7);
insert into public.activos (empresa_id,padre_id,nombre,mantenimiento_modo,mantenimiento_cada_meses)
 values ('00000000-0000-4000-8000-000000000712','00000000-0000-4000-8000-000000000714','Motor',2,3);
do $$
begin
  assert (select count(*) from public.activos) = 2, 'Aislamiento por empresa';
  assert (select mantenimiento_cada_meses from public.activos where nombre='Motor') = 3, 'Componente independiente';
  begin
    insert into public.activos(empresa_id,nombre) values ('00000000-0000-4000-8000-000000000713','Ajeno');
    raise exception 'Ha permitido escribir en otra empresa';
  exception when insufficient_privilege then null; end;
  begin
    update public.activos set uso_horas=25 where id='00000000-0000-4000-8000-000000000714';
    raise exception 'Ha permitido más de 24 horas diarias';
  exception when check_violation then null; end;
  begin
    update public.activos set mantenimiento_ultimo_horas=2000 where id='00000000-0000-4000-8000-000000000714';
    raise exception 'Ha permitido una lectura anterior mayor que la actual';
  exception when check_violation then null; end;
end $$;
rollback;
select 'PRUEBA_OK: persistencia, intervalos independientes y RLS de dos empresas' as resultado;
