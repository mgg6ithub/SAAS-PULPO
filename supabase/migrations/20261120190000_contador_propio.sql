-- Pultec: un componente puede llevar su propio contador (p. ej. unas ruedas cambiadas). Sus horas parten de su
-- lectura (horas, lectura_fecha) y suben al ritmo de su activo principal. Sin él, usa el contador del principal.

alter table public.activos add column if not exists contador_propio boolean not null default false;
comment on column public.activos.contador_propio is
  'Componente con contador propio: sus horas parten de su lectura y suben al ritmo del activo principal.';

-- Horas de hoy: la lectura del componente si tiene contador propio (si no, la del principal); el ritmo, el del
-- principal. Igual que la app (`horasHoy`).
create or replace function private.horas_hoy(a public.activos) returns numeric
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := coalesce(private.raiz(a.id), a);
  l public.activos := case when a.contador_propio and a.padre_id is not null then a else r end;
  desde date := coalesce(l.lectura_fecha, current_date);
  turnos numeric := 0;
begin
  if r.uso_planificado then
    select coalesce(sum((t.value)::numeric), 0) into turnos
    from jsonb_each_text(r.turnos) t
    where t.key::date > desde and t.key::date <= current_date;
    return coalesce(l.horas, 0) + turnos * coalesce(r.horas_turno, 8);
  end if;
  return coalesce(l.horas, 0)
    + coalesce(case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end, 0)
      * greatest(0, current_date - desde);
end $$;
