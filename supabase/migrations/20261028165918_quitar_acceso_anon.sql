-- Supabase da permisos a anon por defecto en public; Pultec solo trabaja con sesión iniciada.
revoke all on
  public.empresas, public.miembros, public.clientes, public.trabajadores, public.trabajos,
  public.trabajo_trabajadores, public.trabajo_historial, public.automatizaciones, public.etiquetas
  from anon;
