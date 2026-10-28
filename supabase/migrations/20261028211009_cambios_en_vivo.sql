-- DEV-022: cambios en vivo entre usuarios. Las tablas de la empresa se publican en Supabase Realtime;
-- cada cliente solo recibe las filas que su RLS le deja ver (los borrados llegan solo con la clave).
alter publication supabase_realtime add table
  public.clientes,
  public.trabajadores,
  public.etiquetas,
  public.trabajos,
  public.trabajo_trabajadores,
  public.trabajo_historial,
  public.automatizaciones,
  public.trabajo_precios,
  public.informes,
  public.documentos;
