-- Pultec: un componente puede llevar su propio contador (p. ej. una correa que se cambia cada 100 h): su lectura
-- (horas, lectura_fecha) y su ritmo de uso (uso_horas, uso_semanal), independientes del activo principal. Sus
-- mantenimientos por horas se calculan con ese contador. Sin él, usa el contador del principal.

alter table public.activos add column if not exists contador_propio boolean not null default false;
comment on column public.activos.contador_propio is
  'Componente con contador propio: sus horas y su ritmo son suyos, no los del activo principal.';

-- De quién son las horas y el ritmo: el componente con contador propio; si no, su activo principal. Igual que la
-- app (`contadorDe`).
create or replace function private.contador_de(a public.activos) returns public.activos
language sql stable set search_path = '' as $$
  select case when a.contador_propio and a.padre_id is not null then a
              else coalesce(private.raiz(a.id), a) end
$$;

create or replace function private.horas_hoy(a public.activos) returns numeric
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := private.contador_de(a);
  desde date := coalesce(r.lectura_fecha, current_date);
  turnos numeric := 0;
begin
  if r.uso_planificado then
    select coalesce(sum((t.value)::numeric), 0) into turnos
    from jsonb_each_text(r.turnos) t
    where t.key::date > desde and t.key::date <= current_date;
    return coalesce(r.horas, 0) + turnos * coalesce(r.horas_turno, 8);
  end if;
  return coalesce(r.horas, 0)
    + coalesce(case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end, 0)
      * greatest(0, current_date - desde);
end $$;

create or replace function private.proximo_estimado(p public.planes_mantenimiento) returns date
language plpgsql stable set search_path = '' as $$
declare
  a public.activos;
  r public.activos;
  quedan numeric;
  ritmo numeric;
  d date;
begin
  if p.proximo is not null then return p.proximo; end if;
  if p.cada_dias is not null then return coalesce(p.ultimo, current_date) + p.cada_dias; end if;
  if p.cada_horas is null then return null; end if;
  select * into a from public.activos where id = p.activo_id;
  if a.id is null then return null; end if;
  r := private.contador_de(a);
  quedan := p.cada_horas - (private.horas_hoy(a) - coalesce(p.ultimo_horas, 0));
  if quedan <= 0 then return current_date; end if;
  if r.uso_planificado then
    for i in 1..400 loop
      d := current_date + i;
      quedan := quedan - coalesce((r.turnos ->> to_char(d, 'YYYY-MM-DD'))::numeric, 0) * coalesce(r.horas_turno, 8);
      if quedan <= 0 then return d; end if;
    end loop;
    return null;
  end if;
  ritmo := case when r.uso_semanal then r.uso_horas / 7 else r.uso_horas end;
  if coalesce(ritmo, 0) <= 0 then return null; end if;
  return current_date + ceil(quedan / ritmo)::integer;
end $$;

create or replace function private.dias_hasta_aviso(a public.activos, cuando date) returns integer
language plpgsql stable set search_path = '' as $$
declare
  r public.activos := private.contador_de(a);
  n integer := 0;
begin
  if cuando is null then return null; end if;
  if not r.uso_planificado then return cuando - current_date; end if;
  select count(*) into n
  from generate_series(current_date + 1, cuando, interval '1 day') d
  where coalesce((r.turnos ->> to_char(d, 'YYYY-MM-DD'))::numeric, 0) > 0;
  return n;
end $$;

revoke all on function private.contador_de(public.activos) from public, anon, authenticated;
