#!/usr/bin/env python3
"""Pulpo en vivo: como Live Server, pero para Flutter web.

Arranca la app en http://localhost:8080 y, cada vez que cambia un .dart de lib/,
hace hot reload (r) sin perder el estado; si cambian assets o pubspec, o Flutter rechaza
el reload (cambios de estructura), hot restart (R).

Uso (desde app/):  python3 tool/vivo.py     · Ctrl+C para parar.
                   python3 tool/vivo.py --industrial  → iPultec (MARCA=industrial) en :8081.
"""

import os
import subprocess
import sys
import threading
import time

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDUSTRIAL = "--industrial" in sys.argv
PUERTO = os.environ.get("PUERTO", "8081" if INDUSTRIAL else "8080")


def huella(rutas):
    """Fecha de modificación de cada archivo vigilado."""
    out = {}
    for raiz in rutas:
        p = os.path.join(APP, raiz)
        if os.path.isfile(p):
            out[p] = os.path.getmtime(p)
            continue
        for d, _, fs in os.walk(p):
            for f in fs:
                if not f.startswith("."):
                    q = os.path.join(d, f)
                    out[q] = os.path.getmtime(q)
    return out


def main():
    flutter = subprocess.Popen(
        ["flutter", "run", "-d", "web-server", "--web-port", PUERTO, "--web-hostname", "localhost"]
        + (["--dart-define=MARCA=industrial"] if INDUSTRIAL else []),
        cwd=APP,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    print(f"\n🐙 {'iPultec' if INDUSTRIAL else 'Pulpo'} en vivo → http://localhost:{PUERTO}  (Ctrl+C para parar)\n", flush=True)

    def enviar(tecla):
        try:
            flutter.stdin.write(tecla)
            flutter.stdin.flush()
        except (BrokenPipeError, ValueError):
            pass

    def vigilar():
        codigo, resto = huella(["lib"]), huella(["assets", "pubspec.yaml"])
        while flutter.poll() is None:
            time.sleep(0.6)
            c, r = huella(["lib"]), huella(["assets", "pubspec.yaml"])
            if r != resto:
                enviar("R")
            elif c != codigo:
                enviar("r")
            codigo, resto = c, r

    def leer():
        # Repite la salida de Flutter y, si rechaza el hot reload, hace hot restart.
        for linea in flutter.stdout:
            print(linea, end="", flush=True)
            if "Hot reload rejected" in linea:
                # Esperar a que Flutter termine con el reload fallido; si no, ignora la R.
                threading.Timer(1.5, enviar, ["R"]).start()

    threading.Thread(target=vigilar, daemon=True).start()
    threading.Thread(target=leer, daemon=True).start()
    try:
        flutter.wait()
    except KeyboardInterrupt:
        enviar("q")
        flutter.wait(timeout=10)
    sys.exit(flutter.returncode or 0)


if __name__ == "__main__":
    main()
