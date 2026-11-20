-- Pultec: las OT no se borran, se cancelan (estado 3) y quedan en el histórico.
--  · la OT de un mantenimiento vigente no se cancela (se volvería a crear sola): antes se pausa el mantenimiento;
--  · al cancelar una OT, su incidencia vuelve a abierta;
--  · un mantenimiento pausado (activa = false) no crea la siguiente; al reanudarlo, `planes_asegura_ot` crea la suya.

-- No cancelar la OT de un mantenimiento vigente.
create or replace function private.ot_no_cancelar_vigente() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 3 and old.estado is distinct from 3 and new.plan_id is not null
     and exists (select 1 from public.planes_mantenimiento p where p.id = new.plan_id and p.activa) then
    raise exception 'La orden de un mantenimiento vigente no se cancela: pausa antes el mantenimiento.';
  end if;
  return new;
end $$;

drop trigger if exists trabajos_no_cancelar_vigente on public.trabajos;
create trigger trabajos_no_cancelar_vigente before update of estado on public.trabajos
  for each row execute function private.ot_no_cancelar_vigente();

-- La OT que resuelve una incidencia la completa al cerrarse; cancelada, la incidencia vuelve a abierta.
create or replace function private.ot_cerrada_incidencias() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 2 and old.estado is distinct from 2 then
    update public.incidencias set estado = 2 where trabajo_id = new.id and estado in (0, 1);
  elsif new.estado = 3 and old.estado is distinct from 3 then
    update public.incidencias set estado = 0 where trabajo_id = new.id and estado = 1;
  elsif old.estado = 2 and new.estado <> 2 then
    update public.incidencias set estado = 1 where trabajo_id = new.id and estado = 2;
  end if;
  return new;
end $$;

revoke all on function private.ot_no_cancelar_vigente(), private.ot_cerrada_incidencias()
  from public, anon, authenticated;
