#!/usr/bin/env python3
"""Landing en local + pasarela a la Supabase local, todo en un solo puerto (8001). Sin dependencias.

El navegador solo tiene que llegar a este puerto (y al de la app, 8000): las llamadas a /auth/v1, /rest/v1,
/functions/v1, /storage/v1, /realtime/v1 (websocket incluido) y /graphql/v1 se reenvían por dentro de la máquina a
la Supabase local (127.0.0.1:54321). Así no hace falta reenviar el puerto 54321 hasta el equipo desde el que se
abre (con VS Code Remote-SSH ese puerto puede estar ocupado en el portátil, p. ej. por otra Supabase).

    python3 tool/landing_local.py            (lo lanza ./entorno.sh landing)
"""
import http.client
import http.server
import os
import socket
import socketserver
import sys
import threading

PUERTO = int(os.environ.get("PUERTO_LANDING", "8001"))
SUPABASE = ("127.0.0.1", 54321)
LANDING = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "landing")
RUTAS_SUPABASE = ("/auth/v1/", "/rest/v1/", "/functions/v1/", "/storage/v1/", "/realtime/v1/", "/graphql/v1")
# Cabeceras de un solo salto: no se reenvían (cada lado de la pasarela pone las suyas).
SALTO = {"connection", "keep-alive", "proxy-connection", "transfer-encoding", "te", "trailer", "upgrade",
         "proxy-authenticate", "proxy-authorization", "content-length", "date", "server"}


class Manejador(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=LANDING, **kwargs)

    def _es_supabase(self):
        return self.path.startswith(RUTAS_SUPABASE)

    def do_GET(self):
        self._supabase() if self._es_supabase() else super().do_GET()

    def do_HEAD(self):
        self._supabase() if self._es_supabase() else super().do_HEAD()

    def _solo_supabase(self):
        self._supabase() if self._es_supabase() else self.send_error(405)

    do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = _solo_supabase

    def _supabase(self):
        if self.headers.get("Upgrade", "").lower() == "websocket":
            return self._tunel()
        largo = int(self.headers.get("Content-Length") or 0)
        cuerpo = self.rfile.read(largo) if largo else None
        cabeceras = {k: v for k, v in self.headers.items() if k.lower() not in SALTO | {"host"}}
        cabeceras["Host"] = "%s:%d" % SUPABASE
        try:
            c = http.client.HTTPConnection(*SUPABASE, timeout=120)
            c.request(self.command, self.path, body=cuerpo, headers=cabeceras)
            r = c.getresponse()
            datos = r.read()
        except OSError:
            self.send_error(502, "La Supabase local no responde (./entorno.sh arrancar)")
            return
        self.send_response(r.status, r.reason)
        for k, v in r.getheaders():
            if k.lower() not in SALTO:
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(datos)
        c.close()

    def _tunel(self):
        """Websocket (realtime): se reenvía la petición tal cual y luego se copian los bytes en los dos sentidos."""
        try:
            s = socket.create_connection(SUPABASE, timeout=10)
        except OSError:
            self.send_error(502, "La Supabase local no responde")
            return
        s.settimeout(None)
        lineas = ["%s %s HTTP/1.1" % (self.command, self.path), "Host: %s:%d" % SUPABASE]
        lineas += ["%s: %s" % (k, v) for k, v in self.headers.items() if k.lower() != "host"]
        s.sendall(("\r\n".join(lineas) + "\r\n\r\n").encode("latin-1"))
        cliente = self.connection
        cliente.settimeout(None)

        def copiar(origen, destino):
            try:
                while True:
                    d = origen.recv(65536)
                    if not d:
                        break
                    destino.sendall(d)
            except OSError:
                pass
            finally:
                for x in (origen, destino):
                    try:
                        x.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass

        hilo = threading.Thread(target=copiar, args=(s, cliente), daemon=True)
        hilo.start()
        copiar(cliente, s)
        hilo.join()
        s.close()
        self.close_connection = True

    def log_message(self, formato, *args):
        # Solo errores y llamadas a Supabase (los archivos de la landing serían mucho ruido).
        if self._es_supabase() or (args and str(args[1]).startswith(("4", "5"))):
            sys.stderr.write("%s %s\n" % (self.log_date_time_string(), formato % args))


class Servidor(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print("Landing en http://localhost:%d  ·  Supabase local por la misma dirección (%s:%d)" % ((PUERTO,) + SUPABASE),
          flush=True)
    try:
        Servidor(("127.0.0.1", PUERTO), Manejador).serve_forever()
    except KeyboardInterrupt:
        pass
