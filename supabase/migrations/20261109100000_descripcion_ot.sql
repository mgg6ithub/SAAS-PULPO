-- OT: breve descripción de lo que hay que hacer. Al crearse desde un mantenimiento, copia la de este.
alter table public.trabajos add column if not exists descripcion text not null default '';

create or replace function private.descripcion_desde_plan() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Solo en filas nuevas: un upsert de una OT ya creada (descripción borrada a mano) no la vuelve a rellenar.
  if new.plan_id is not null and coalesce(new.descripcion, '') = ''
     and not exists (select 1 from public.trabajos t where t.id = new.id) then
    select p.descripcion into new.descripcion
    from public.planes_mantenimiento p
    where p.id = new.plan_id and p.empresa_id = new.empresa_id;
    new.descripcion := coalesce(new.descripcion, '');
  end if;
  return new;
end $$;

drop trigger if exists trabajos_descripcion_plan on public.trabajos;
create trigger trabajos_descripcion_plan before insert on public.trabajos
  for each row execute function private.descripcion_desde_plan();

-- Las OT que ya hay, con la descripción de su mantenimiento.
update public.trabajos t set descripcion = p.descripcion
from public.planes_mantenimiento p
where t.plan_id = p.id and t.descripcion = '' and p.descripcion <> '';
