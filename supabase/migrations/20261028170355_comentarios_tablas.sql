-- Descripciones en la propia base: el mapa de Cerebro las lee de aquí.
comment on table public.empresas is 'Cada espacio de trabajo separado (p. ej. una empresa de jardinería). Todo lo demás cuelga de una empresa.';
comment on table public.miembros is 'Qué cuenta pertenece a qué empresa y con qué rol (admin o trabajador). Una cuenta puede estar en varias.';
comment on table public.clientes is 'Clientes a los que se da mantenimiento (comunidades, colegios, hospitales...). Modelo Cliente de la app.';
comment on table public.trabajadores is 'Técnicos de la empresa y sus competencias. Modelo Trabajador de la app.';
comment on table public.trabajos is 'Plantillas, trabajos y subtrabajos (padre_id). Modelo Tarea de la app.';
comment on table public.trabajo_trabajadores is 'Qué trabajadores tiene asignados cada trabajo (Tarea.trabajadorIds).';
comment on table public.trabajo_historial is 'Días en que se hizo cada trabajo (Tarea.historial).';
comment on table public.automatizaciones is 'Reglas de email de un trabajo (DEV-008). El envío real llega en DEV-013.';
comment on table public.etiquetas is 'Etiquetas con nombre y color para marcar trabajos.';

comment on function private.es_miembro(uuid) is 'La cuenta con sesión pertenece a esa empresa. Definer para evitar recursión de RLS en miembros.';
comment on function private.es_admin(uuid) is 'La cuenta con sesión es admin de esa empresa. Base de casi todas las políticas.';
comment on function private.empresa_sin_miembros(uuid) is 'Permite que quien crea una empresa vacía se añada como primer admin.';
comment on function private.tocar_updated_at() is 'Trigger: actualiza updated_at en cada UPDATE.';
