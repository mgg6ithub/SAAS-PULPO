# Entorno local y pagos: cambios del 24-11-2026

Nota para el agente que trabaje en otro equipo (p. ej. el Mac). Resume lo que se montó en el Linux (RHEL, 3.6 GB RAM,
podman, abierto desde Windows con VS Code Remote-SSH) y qué hay que hacer para trabajar igual.

## Qué cambió en el entorno (`entorno.sh`)
| Orden | Qué hace ahora |
|---|---|
| `arrancar` | Supabase en modo **ligero** (sin Studio, Edge Functions, Mailpit ni imgproxy): ~0.7 GB en vez de ~1.3 GB. Al terminar aplica las migraciones pendientes |
| `migrar` | Aplica solo las migraciones pendientes a la base local, sin borrar datos |
| `completo` | Todo, Studio incluido (localhost:54323) |
| `funciones` | Sirve las Edge Functions con los secretos de `supabase/.env` |
| `landing` | Landing en :8001 **+ pasarela a Supabase** (`tool/landing_local.py`) |
| `app` | Si la landing está en marcha, la app usa `SUPABASE_URL=http://localhost:8001`; si no, `:54321` |
| `parar` | Antes aplica las pendientes. 1) Guarda como migración `*_cambios_sin_migracion.sql` lo cambiado sin migración (revisarla y hacer commit). 2) Para y **borra la base local** |
| `plan` | Ver el plan de cada cuenta local; `./entorno.sh plan correo premium\|basico` lo cambia sin pagar |

- **Tras un `git pull`:** `arrancar` aplica las migraciones nuevas. Para que se apliquen también con el entorno en marcha hay un hook de git local (`.git/hooks/post-merge` y `post-rewrite`, no se versiona) que ejecuta `./entorno.sh migrar --si-arrancada`. Si cambia una migración ya aplicada o `seed.sql`, hace falta `./entorno.sh reset` (borra los datos locales).
- **La base local es desechable.** `parar` la borra y `arrancar` la reconstruye con migraciones + `seed.sql`. Los datos de prueba que deban quedarse van en el seed.
- **Pasarela (:8001):** existe porque, con VS Code Remote-SSH, el `localhost:54321` del portátil era otra Supabase. Con ella, el navegador solo necesita los puertos 8000 y 8001. En el Mac no hace falta, pero funciona igual.
- **Arreglo en `sb()` con podman:** ahora devuelve el error real de la CLI (antes devolvía el del `chown`).
- **`config.toml`:** `localhost:8000` añadido a las redirecciones permitidas, y `verify_jwt = false` en las funciones nuevas.
- **Seed:** «Mantenimientos Prueba» (`admin@pultec.local`) es **Premium**; las cuentas nuevas empiezan en Básico.

## Landing: entrar y crear cuenta sin salir de ella
- **Cómo funciona:** ventana propia (`landing/index.html`, `styles.css`, `main.js`) que habla con Supabase Auth por HTTP. Al terminar lleva a la app con `#access_token=…`; `supabase_flutter` recoge la sesión.
- **Dirección de Supabase:** en local es `location.origin` (la pasarela); en producción, `gvasthxiqckmekwvhtrg`.
- **El pago nunca se abre solo:** únicamente desde **Ajustes → Plan**.

## Pagos con Stripe
- **El plan es de la EMPRESA:** tabla `suscripciones` (migración `20261124120000_suscripciones.sql`). La app solo la lee (`plan_empresa()`); la escriben las funciones con lo que diga Stripe.
- **Funciones** (`supabase/functions/`; el código común está en `_shared/pagos.ts`):
  - `crear-pago`: abre Checkout. Solo el admin, con IVA 21 % y pidiendo NIF y dirección.
  - `portal-pago`: abre el portal de cliente (tarjeta, mensual/anual, facturas, cancelar).
  - `sincronizar-pago`: la app la llama al volver de Stripe (`?pago=ok|cancelado|portal`), así el plan se ve al instante.
  - `stripe-webhook`: renovaciones y cobros fallidos. Valida la firma y vuelve a pedir el estado a Stripe.
- **App:** Ajustes → **Plan** (solo admin), clase `PlanEmpresa` y métodos de pago en `nube.dart`, y vuelta de Stripe en `acceso.dart`.
- **Producto y precios:** se crean con `supabase/stripe/preparar.sh`, que se puede repetir sin duplicar. Crea `pultec_premium`, los lookup_keys `pultec_premium_mensual` (49 €) y `pultec_premium_anual` (468 €), y el IVA del 21 %. Ya está ejecutado en el modo prueba.
- **Secretos** en `supabase/.env` (**fuera de git**: copiarlo a mano):
  - `STRIPE_SECRET_KEY=sk_test_…`
  - `STRIPE_WEBHOOK_SECRET=whsec_…` (aún vacío)
- **Probado:** pago, cancelación al final del periodo, cancelación efectiva, permisos (solo el admin, vuelta solo a la app, firma del webhook). Tarjeta de prueba `4242 4242 4242 4242`.
- **Pendiente:**
  - **Webhook con avisos reales:** `stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook` y poner el `whsec_` en `.env`.
  - **Límites del plan Básico** (15 activos, 2 técnicos) en la base de datos.
- **Producción:** `supabase secrets set STRIPE_SECRET_KEY=… STRIPE_WEBHOOK_SECRET=…`, ejecutar `preparar.sh` con la clave real, crear el endpoint del webhook en Stripe y subir la migración con la skill `subir-a-produccion`.

## Para trabajar igual en el Mac
1. `git pull`. Copia `supabase/.env` a mano (no está en git).
2. `./entorno.sh parar && ./entorno.sh arrancar`: reconstruye la base con la migración nueva. ⚠ Borra los datos locales.
3. `./entorno.sh landing` y luego `./entorno.sh app`. Si Flutter no está en `/usr/local/flutter-sdk`, pon `FLUTTER_BIN`.
4. Si vas a tocar pagos: `./entorno.sh funciones`.
5. Lo de `sudo`/podman y los scripts `~/s_pultec` (volumen cifrado) solo existen en el Linux. Con Docker Desktop, `entorno.sh` usa la CLI tal cual.
