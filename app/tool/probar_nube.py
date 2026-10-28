#!/usr/bin/env python3
"""Prueba real contra Supabase: crea cuatro cuentas de prueba, lanza test/nube_real_test.dart y las borra siempre.

Uso (desde app/):  python3 tool/probar_nube.py
Necesita la CLI de Supabase enlazada (supabase/ en la raíz del repo) y SUPABASE_ACCESS_TOKEN
(variable de entorno o en un .env: ~/Desktop/PULPO/.env).
"""

import os
import random
import subprocess
import sys

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = os.path.dirname(APP)


def token():
    if os.environ.get("SUPABASE_ACCESS_TOKEN"):
        return os.environ["SUPABASE_ACCESS_TOKEN"]
    for ruta in (os.path.join(RAIZ, ".env"), os.path.join(APP, ".env"), os.path.expanduser("~/Desktop/PULPO/.env")):
        if os.path.exists(ruta):
            for linea in open(ruta):
                if linea.startswith("SUPABASE_ACCESS_TOKEN="):
                    return linea.split("=", 1)[1].strip()
    sys.exit("Falta SUPABASE_ACCESS_TOKEN")


ENV = {**os.environ, "SUPABASE_ACCESS_TOKEN": token()}


def sql(texto):
    r = subprocess.run(["supabase", "db", "query", "--linked", texto], cwd=RAIZ, env=ENV, capture_output=True,
                       text=True, stdin=subprocess.DEVNULL)
    if r.returncode != 0:
        sys.exit(f"SQL falló: {r.stderr.strip() or r.stdout.strip()}")


CREAR = """
with n as (
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at,
    updated_at, raw_app_meta_data, raw_user_meta_data, confirmation_token, recovery_token, email_change,
    email_change_token_new)
  select gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e,
    crypt('prueba-123456', gen_salt('bf')), now(), now(), now(),
    '{{"provider":"email","providers":["email"]}}', '{{}}', '', '', '', ''
  from unnest(array['{a}','{b}','{c}','{d}']) e returning id, email)
insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select id::text, id, jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true), 'email', now(), now(), now()
from n;
"""

# Primero las empresas de esas cuentas (arrastran todos sus datos) y luego las cuentas.
BORRAR = """
with u as (select id from auth.users where email in ('{a}','{b}','{c}','{d}')),
e as (delete from public.empresas where creada_por in (select id from u) returning id)
delete from auth.users where id in (select id from u);
"""


def main():
    n = random.randint(10000, 99999)
    a, b, c, d = (f"prueba-{x}-{n}@pultec.com" for x in "abcd")
    sql(CREAR.format(a=a, b=b, c=c, d=d))
    try:
        r = subprocess.run(["flutter", "test", "test/nube_real_test.dart"], cwd=APP, stdin=subprocess.DEVNULL,
                           env={**ENV, "SB_CORREO_A": a, "SB_CORREO_B": b, "SB_CORREO_C": c, "SB_CORREO_D": d})
        codigo = r.returncode
    finally:
        sql(BORRAR.format(a=a, b=b, c=c, d=d))
    print("Cuentas y datos de prueba borrados." if codigo == 0 else "Prueba FALLIDA (cuentas y datos de prueba borrados).")
    sys.exit(codigo)


if __name__ == "__main__":
    main()
