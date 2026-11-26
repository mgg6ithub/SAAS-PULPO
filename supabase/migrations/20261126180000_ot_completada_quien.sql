-- Cuándo (con hora) y quién completó cada orden. Lo escribe la base, así vale igual para oficina y técnico.
-- El nombre se guarda tal cual en ese momento: el histórico no cambia si luego se borra o renombra la cuenta.
alter table public.trabajos
  add column if not exists completada_el timestamptz,
  add column if not exists completada_por text;

-- Las ya completadas con parte: la hora y el técnico de su último parte.
update public.trabajos t set
  completada_el = i.created_at,
  completada_por = (select nullif(trim(concat_ws(' ', w.nombre, w.apellidos)), '') from public.trabajadores w where w.id = i.trabajador_id)
from (select distinct on (trabajo_id) trabajo_id, trabajador_id, created_at
      from public.informes order by trabajo_id, created_at desc) i
where i.trabajo_id = t.id and t.estado = 2;

create or replace function private.ot_completada_quien() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 2 and old.estado is distinct from 2 then
    new.completada_el := now();
    new.completada_por := coalesce(
      (select nullif(trim(concat_ws(' ', w.nombre, w.apellidos)), '')
         from public.miembros m join public.trabajadores w on w.id = m.trabajador_id
        where m.usuario_id = (select auth.uid()) and m.empresa_id = new.empresa_id limit 1),
      (select nullif(trim(p.nombre), '') from public.perfiles p where p.usuario_id = (select auth.uid())),
      (select u.email from auth.users u where u.id = (select auth.uid())));
  elsif new.estado is distinct from 2 then
    new.completada_el := null;
    new.completada_por := null;
  end if;
  return new;
end $$;

-- Va después de limitar_cambios_trabajador (los triggers se ejecutan por orden alfabético).
drop trigger if exists trabajos_completada_quien on public.trabajos;
create trigger trabajos_completada_quien before update of estado on public.trabajos
  for each row execute function private.ot_completada_quien();
