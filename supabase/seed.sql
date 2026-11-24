-- Datos de prueba de la Supabase local (`supabase start` / `supabase db reset`). Nunca se cargan en producción.
-- Pultec (industrial) solo deja entrar por invitación, así que aquí van ya una empresa y sus cuentas:
--   admin@pultec.local   / pultec1234  → administrador de «Mantenimientos Prueba»
--   tecnico@pultec.local / pultec1234  → técnico de la misma empresa
-- Plan: «Mantenimientos Prueba» es Premium (sin Stripe, solo para probar). Las cuentas nuevas empiezan en Básico.
-- Ver o cambiar el plan de cualquier cuenta: ./entorno.sh plan [correo premium|basico]

do $$
declare
  admin uuid := '00000000-0000-0000-0000-0000000000a1';
  tecnico uuid := '00000000-0000-0000-0000-0000000000a2';
  empresa uuid := '00000000-0000-0000-0000-0000000000e1';
  u record;
begin
  for u in select * from (values (admin, 'admin@pultec.local'), (tecnico, 'tecnico@pultec.local')) as t(id, correo) loop
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.correo,
            extensions.crypt('pultec1234', extensions.gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), u.id, u.id::text,
            jsonb_build_object('sub', u.id::text, 'email', u.correo, 'email_verified', true),
            'email', now(), now(), now());
  end loop;

  insert into public.empresas (id, nombre, creada_por, marca) values (empresa, 'Mantenimientos Prueba', admin, 'industrial');
  insert into public.miembros (usuario_id, empresa_id, rol) values (admin, empresa, 'admin'), (tecnico, empresa, 'trabajador');
  insert into public.cuentas_marca (usuario_id, marca) values (admin, 'industrial'), (tecnico, 'industrial');
  insert into public.suscripciones (empresa_id, plan, periodo, estado, fin_periodo)
  values (empresa, 'premium', 'mensual', 'active', now() + interval '1 month');
end $$;
