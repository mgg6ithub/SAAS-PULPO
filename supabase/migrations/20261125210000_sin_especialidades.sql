-- Pultec: fuera las especialidades (competencias) de los técnicos; mandan los grupos.
--  · Una OT libre la puede tomar cualquier técnico; si es de un grupo, solo los de ese grupo.
--  · Se vacían las especialidades que pedían los mantenimientos y las OT de las empresas industriales.
create or replace function private.ot_libre_de_mi_categoria(p_trabajo uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.trabajos t
    join public.empresas e on e.id = t.empresa_id and e.marca = 'industrial'
    join public.trabajadores w on w.id = private.mi_trabajador(t.empresa_id) and w.activo
    where t.id = p_trabajo and t.activa and not t.plantilla and t.tipo_mantenimiento is not null
      and t.estado in (0, 1)
      and not exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = t.id)
      and (t.grupo_id is null or t.grupo_id = any (w.grupo_ids))
  )
$$;
comment on function private.ot_libre_de_mi_categoria(uuid) is
  'iPultec: OT activa, sin terminar y sin técnico; si es de un grupo, el técnico de la cuenta está en él.';

update public.planes_mantenimiento p set categoria = ''
  from public.empresas e where e.id = p.empresa_id and e.marca = 'industrial' and p.categoria <> '';
update public.trabajos t set competencias = '{}'
  from public.empresas e where e.id = t.empresa_id and e.marca = 'industrial' and t.competencias <> '{}';
notify pgrst, 'reload schema';
