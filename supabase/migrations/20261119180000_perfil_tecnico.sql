-- El técnico cambia su propia foto y su teléfono desde «Mi perfil» (el resto de su ficha, solo el admin).
-- La foto llega en PNG base64; la app del administrador la sube a Storage al abrir, como las antiguas.
create or replace function public.guardar_mi_perfil(p_empresa uuid, p_foto text, p_telefono text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  w uuid := private.mi_trabajador(p_empresa);
begin
  if w is null then
    raise exception 'Esta cuenta no tiene ficha de técnico';
  end if;
  if length(coalesce(p_foto, '')) > 3000000 then
    raise exception 'La foto es demasiado grande';
  end if;
  update public.trabajadores
     set foto = coalesce(p_foto, ''), telefono = left(coalesce(p_telefono, ''), 40)
   where id = w and empresa_id = p_empresa;
end;
$$;

revoke execute on function public.guardar_mi_perfil(uuid, text, text) from public, anon;
grant execute on function public.guardar_mi_perfil(uuid, text, text) to authenticated;
