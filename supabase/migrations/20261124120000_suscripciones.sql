-- Pultec: planes de pago con Stripe. El plan es de la EMPRESA (no de cada cuenta): paga el admin y todos sus
-- miembros tienen el plan. Sin fila = plan Básico.
-- Quien escribe aquí es solo el servidor (Edge Functions crear-pago y stripe-webhook, con la clave secreta);
-- la app solo lee. Stripe es la fuente de verdad: el webhook copia el estado de la suscripción tal cual.

create table public.suscripciones (
  empresa_id uuid primary key references public.empresas (id) on delete cascade,
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  plan text not null default 'basico' check (plan in ('basico', 'premium')),
  periodo text check (periodo in ('mensual', 'anual')),
  -- Estado de Stripe: active, trialing, past_due, unpaid, canceled, incomplete, incomplete_expired, paused.
  estado text,
  fin_periodo timestamptz,
  cancela_al_final boolean not null default false,
  updated_at timestamptz not null default now()
);

create trigger suscripciones_updated_at before update on public.suscripciones
  for each row execute function private.tocar_updated_at();

alter table public.suscripciones enable row level security;

-- Los miembros de la empresa ven su plan; nadie escribe desde la app (sin políticas de escritura).
create policy suscripciones_select on public.suscripciones for select to authenticated
  using (private.es_miembro(empresa_id));

revoke all on public.suscripciones from anon, authenticated;
grant select on public.suscripciones to authenticated;

-- Plan vigente de una empresa. Premium mientras Stripe la tenga activa; con un cobro fallido (past_due)
-- se mantiene mientras Stripe reintenta, y pasa a Básico cuando Stripe la da por perdida (unpaid/canceled).
create function public.plan_empresa(p_empresa uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when not private.es_miembro(p_empresa) then null
    when exists (
      select 1 from public.suscripciones s
      where s.empresa_id = p_empresa and s.plan = 'premium' and s.estado in ('active', 'trialing', 'past_due')
    ) then 'premium'
    else 'basico'
  end
$$;

revoke execute on function public.plan_empresa(uuid) from public, anon;
grant execute on function public.plan_empresa(uuid) to authenticated;
