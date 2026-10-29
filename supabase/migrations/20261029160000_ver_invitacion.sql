-- DEV-019: la pantalla de acceso dice a qué empresa y con qué rol te une una invitación, antes de entrar.
-- El código (64 caracteres al azar) es el secreto del enlace: quien lo tiene ya puede aceptarlo, así que
-- puede ver el nombre de la empresa, el rol y la ficha. Si no vale (usada, caducada o no existe), no devuelve nada.
create function public.ver_invitacion(p_codigo text)
returns table (empresa text, rol text, trabajador text)
language sql stable security definer set search_path = '' as $$
  select e.nombre, i.rol, t.nombre
  from public.invitaciones i
  join public.empresas e on e.id = i.empresa_id
  left join public.trabajadores t on t.id = i.trabajador_id
  where i.codigo = p_codigo and i.usada_por is null and i.caduca_en >= now()
$$;
revoke execute on function public.ver_invitacion(text) from public;
grant execute on function public.ver_invitacion(text) to anon, authenticated;
comment on function public.ver_invitacion(text) is 'Empresa, rol y ficha de una invitación válida (para la pantalla de acceso).';
