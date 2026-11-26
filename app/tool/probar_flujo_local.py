#!/usr/bin/env python3
"""Prueba del núcleo de Pultec contra la Supabase LOCAL, para lanzarla tras cualquier cambio grande:
  1. test/flujo_pultec_real_test.dart (base real): activo y componente con sus mantenimientos → la base crea las OT
     → el técnico las ve, empieza una, la cierra con su parte y comunica incidencias → el administrador la ve hecha,
     el mantenimiento reiniciado y la siguiente OT creada; OT para una incidencia, desestimar la otra, etc.
  2. test/incidencias_flujo_test.dart (interfaz): de la lista de incidencias a la OT y vuelta, sin recargar.
Crea dos cuentas de prueba en la base local y las borra al acabar, falle o no. Producción no se toca.

Uso:  ./entorno.sh probar   (o, desde app/:  python3 tool/probar_flujo_local.py)
Necesita la Supabase local arrancada (./entorno.sh arrancar).
"""

import os
import random
import subprocess
import sys

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = "http://127.0.0.1:54321"
CLAVE = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

# Mismas cuentas y empresa que la prueba de producción (tool/probar_flujo_pultec.py), pero en la base local.
_src = open(os.path.join(APP, "tool/probar_flujo_pultec.py")).read()
CREAR = _src.split('CREAR = """')[1].split('"""')[0]
BORRAR = _src.split('BORRAR = """')[1].split('"""')[0]


def sql(texto):
    r = subprocess.run(
        ["docker", "exec", "-i", "supabase_db_develop", "psql", "-U", "postgres", "-v", "ON_ERROR_STOP=1", "-q"],
        input=texto, text=True, capture_output=True)
    if r.returncode:
        sys.exit("No se pudo hablar con la base local (¿./entorno.sh arrancar?):\n" + r.stderr)


def flutter_test(archivo, extra_env=None):
    return subprocess.run(
        ["flutter", "test", "--dart-define=MARCA=industrial", f"--dart-define=SUPABASE_URL={URL}",
         f"--dart-define=SUPABASE_PUBLICABLE={CLAVE}", archivo],
        cwd=APP, stdin=subprocess.DEVNULL, env={**os.environ, **(extra_env or {})}).returncode


def main():
    n = random.randint(10000, 99999)
    a, b = (f"prueba-flujo-{x}-{n}@ipultec.com" for x in "ab")
    sql(CREAR.format(a=a, b=b))
    try:
        real = flutter_test("test/flujo_pultec_real_test.dart", {"SB_ADMIN": a, "SB_TECNICO": b})
    finally:
        sql(BORRAR.format(a=a, b=b))
    interfaz = flutter_test("test/incidencias_flujo_test.dart")
    ok = real == 0 and interfaz == 0
    print("\nNúcleo de Pultec: TODO BIEN." if ok else
          f"\nNúcleo de Pultec: FALLA ({'flujo real' if real else ''}{' y ' if real and interfaz else ''}"
          f"{'interfaz de incidencias' if interfaz else ''}).")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
