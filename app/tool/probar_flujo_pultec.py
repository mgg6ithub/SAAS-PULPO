#!/usr/bin/env python3
"""Prueba real del flujo de Pultec contra Supabase: administrador → activo y mantenimientos → OT automáticas →
técnico invitado que cierra una → lo que ven los dos. Crea dos cuentas @ipultec.com de prueba y una empresa
industrial, lanza test/flujo_pultec_real_test.dart y lo borra todo siempre, falle o no.

Uso (desde app/):  python3 tool/probar_flujo_pultec.py
Necesita la CLI de Supabase enlazada y SUPABASE_ACCESS_TOKEN (variable de entorno o ~/Desktop/PULTEC/.env).
"""

import random
import subprocess
import sys

from probar_nube import APP, ENV, sql

CREAR = """
with n as (
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at,
    updated_at, raw_app_meta_data, raw_user_meta_data, confirmation_token, recovery_token, email_change,
    email_change_token_new)
  select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e,
    crypt('prueba-123456', gen_salt('bf')), now(), now(), now(),
    '{{"provider":"email","providers":["email"]}}', '{{}}', '', '', '', ''
  from unnest(array['{a}','{b}']) e returning id, email),
i as (
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select id::text, id, jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), 'email', now(),
    now(), now() from n returning user_id),
m as (insert into public.cuentas_marca (usuario_id, marca) select id, 'industrial' from n returning usuario_id),
e as (
  insert into public.empresas (nombre, creada_por, marca)
  select 'Planta de prueba', id, 'industrial' from n where email = '{a}' returning id, creada_por)
insert into public.miembros (usuario_id, empresa_id, rol) select creada_por, id, 'admin' from e;
"""

BORRAR = """
with u as (select id from auth.users where email in ('{a}','{b}')),
e as (delete from public.empresas where creada_por in (select id from u) returning id)
delete from auth.users where id in (select id from u);
"""


def main():
    n = random.randint(10000, 99999)
    a, b = (f"prueba-flujo-{x}-{n}@ipultec.com" for x in "ab")
    sql(CREAR.format(a=a, b=b))
    try:
        r = subprocess.run(
            ["flutter", "test", "--dart-define=MARCA=industrial", "test/flujo_pultec_real_test.dart"],
            cwd=APP, stdin=subprocess.DEVNULL, env={**ENV, "SB_ADMIN": a, "SB_TECNICO": b})
        codigo = r.returncode
    finally:
        sql(BORRAR.format(a=a, b=b))
    print("Cuentas y datos de prueba borrados." if codigo == 0 else "Prueba FALLIDA (cuentas y datos de prueba borrados).")
    sys.exit(codigo)


if __name__ == "__main__":
    main()
