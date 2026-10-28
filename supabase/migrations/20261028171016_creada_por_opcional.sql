-- Borrar una cuenta no debe quedar bloqueado por las empresas que creó: la empresa sigue (con sus miembros).
-- El insert sigue exigiendo creada_por = auth.uid() (política empresas_insert).
alter table public.empresas alter column creada_por drop not null;
alter table public.empresas drop constraint empresas_creada_por_fkey;
alter table public.empresas
  add constraint empresas_creada_por_fkey foreign key (creada_por) references auth.users (id) on delete set null;
