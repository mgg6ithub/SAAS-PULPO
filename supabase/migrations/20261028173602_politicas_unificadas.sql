-- Una sola política por tabla y acción (administrador o trabajador en la misma condición):
-- evita que Postgres evalúe varias a la vez y el aviso multiple_permissive_policies.

-- clientes: el administrador, todo; el trabajador, solo clientes de sus trabajos.
drop policy clientes_admin on public.clientes;
drop policy clientes_de_mis_trabajos on public.clientes;
create policy clientes_select on public.clientes for select to authenticated
  using (private.es_admin(empresa_id) or exists (select 1 from public.trabajos t where t.cliente_id = clientes.id));
create policy clientes_insert on public.clientes for insert to authenticated with check (private.es_admin(empresa_id));
create policy clientes_update on public.clientes for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy clientes_delete on public.clientes for delete to authenticated using (private.es_admin(empresa_id));

-- trabajadores: el trabajador solo ve su ficha.
drop policy trabajadores_admin on public.trabajadores;
drop policy trabajadores_propio on public.trabajadores;
create policy trabajadores_select on public.trabajadores for select to authenticated
  using (private.es_admin(empresa_id) or id = private.mi_trabajador(empresa_id));
create policy trabajadores_insert on public.trabajadores for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy trabajadores_update on public.trabajadores for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy trabajadores_delete on public.trabajadores for delete to authenticated
  using (private.es_admin(empresa_id));

-- trabajo_trabajadores: el trabajador solo ve sus asignaciones.
drop policy trabajo_trabajadores_admin on public.trabajo_trabajadores;
drop policy trabajo_trabajadores_propio on public.trabajo_trabajadores;
create policy trabajo_trabajadores_select on public.trabajo_trabajadores for select to authenticated
  using (private.es_admin(empresa_id) or trabajador_id = private.mi_trabajador(empresa_id));
create policy trabajo_trabajadores_insert on public.trabajo_trabajadores for insert to authenticated
  with check (private.es_admin(empresa_id));
create policy trabajo_trabajadores_update on public.trabajo_trabajadores for update to authenticated
  using (private.es_admin(empresa_id)) with check (private.es_admin(empresa_id));
create policy trabajo_trabajadores_delete on public.trabajo_trabajadores for delete to authenticated
  using (private.es_admin(empresa_id));

-- trabajos: el trabajador ve y actualiza (estado y fechas, ver trigger) los suyos.
drop policy trabajos_admin on public.trabajos;
drop policy trabajos_asignados_select on public.trabajos;
drop policy trabajos_asignados_update on public.trabajos;
create policy trabajos_select on public.trabajos for select to authenticated
  using (
    private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id)
  );
create policy trabajos_insert on public.trabajos for insert to authenticated with check (private.es_admin(empresa_id));
create policy trabajos_update on public.trabajos for update to authenticated
  using (
    private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id)
  )
  with check (
    private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajos.id)
  );
create policy trabajos_delete on public.trabajos for delete to authenticated using (private.es_admin(empresa_id));

-- trabajo_historial: el trabajador marca y desmarca como hecho sus trabajos.
drop policy trabajo_historial_admin on public.trabajo_historial;
drop policy historial_de_mis_trabajos on public.trabajo_historial;
create policy trabajo_historial_todo on public.trabajo_historial for all to authenticated
  using (
    private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajo_historial.trabajo_id)
  )
  with check (
    private.es_admin(empresa_id)
    or exists (select 1 from public.trabajo_trabajadores tt where tt.trabajo_id = trabajo_historial.trabajo_id)
  );
