# Pultec

SaaS de automatización de mantenimiento para empresas pequeñas de mantenimiento (ascensores, contra incendios…). Gestiona sus clientes (edificios, colegios, hospitales…), sus trabajadores, qué tareas puede hacer cada uno y cuándo toca cada mantenimiento. Objetivo: automatizar el mantenimiento y ganar inteligencia con los datos.

- Nombre: Pultec (antes Pulpo; logo: pulpo morado). La variante residencial se llama Pulcón.
- Documentación y plan: Cerebro, `~/Desktop/CEREBRO/Proyectos/Pultec/` → empezar por `MOC - Pultec.md` y `Producto/Plan general - Pultec.md` (fuente: `Plan_PULTEC.pdf`).
- Para documentar usa la skill `documentar-pulpo`.
- Stack: Flutter desde el prototipo (web primero; SDK en `C:\Users\mgg\flutter`), proyecto en `app/`; datos en local y Supabase después.
- UI: minimalista pero muy funcional, visual y con color.
- Idioma de documentación: español.

## Interfaz: coherencia visual obligatoria
Antes de implementar, cambiar o crear cualquier vista:
- Lee `~/Desktop/CEREBRO/Proyectos/Pultec/Pulcón/Apariencia/MOC - Apariencia.md` (sistema, componentes, vistas de referencia y reglas) con la skill `pulpo-coherencia-visual`.
- Estilo = demo de la landing (`landing/`): tarjetas blancas de borde fino sin sombra, tinta + morado del logo, Geist, mucho aire, pocos botones.
- Solo tokens de `app/lib/theme.dart` (`P`, `margenPagina`) y componentes de `app/lib/widgets.dart`; nada de valores sueltos. Formularios con `VentanaFormulario` + `Bloque`.
- Pensado para portátil 1080p: lo importante (calendario, mapa) ocupa el alto.
- **Cuantos menos iconos, mejor**: el color (puntos, barritas) sustituye al icono.
- Probar en vivo: `cd app && python3 tool/vivo.py` (localhost:8080, recarga al guardar).
- Jobber y OptimoRoute (`Producto/Referencias/` en Cerebro) son referencia de funcionalidad, no de estilo.

## Base de datos: desarrollo en local, producción solo con la skill
- **Leer primero `ENTORNO_LOCAL.md`**: cambios del entorno local (modo ligero, base desechable, pasarela :8001) y de pagos con Stripe, y cómo adaptarse en otro equipo.
- Se desarrolla SIEMPRE contra la Supabase local: `./entorno.sh arrancar` (contenedores, migraciones + `supabase/seed.sql`) y `./entorno.sh app` (Pultec en localhost:8000 contra la local). Cuentas de prueba: `admin@pultec.local` / `tecnico@pultec.local`, contraseña `pultec1234`. `arrancar` es el modo ligero (sin Studio, Edge Functions ni Mailpit, para máquinas con poca RAM); `./entorno.sh completo` lo levanta todo (Studio: localhost:54323) y `./entorno.sh funciones` sirve las Edge Functions sobre el modo ligero.
- Cambios de esquema solo como migración en `supabase/migrations/` (`supabase migration new`); `./entorno.sh reset` recrea la local desde cero.
- La base local es desechable: `./entorno.sh parar` guarda como migración `*_cambios_sin_migracion.sql` lo que se haya cambiado en el esquema sin migración (revisarla y hacer commit), y después borra la base; `arrancar` la reconstruye con migraciones + seed. Datos de prueba que deban quedarse → `supabase/seed.sql`.
- Pagos con Stripe: el plan es de la EMPRESA (tabla `suscripciones`, solo la escriben las funciones; la app lee con `plan_empresa()`). Funciones: `crear-pago` (Checkout), `portal-pago` (portal de cliente), `sincronizar-pago` (la app la llama al volver de Stripe con `?pago=ok|cancelado|portal`) y `stripe-webhook` (renovaciones, cobros fallidos; valida la firma). Producto y precios con `supabase/stripe/preparar.sh` (lookup_keys `pultec_premium_mensual|anual`, IVA 21 %), igual en prueba y en real. Secretos en `supabase/.env` (fuera de git): `STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET`; en local se sirven con `./entorno.sh funciones`. Para producción: `supabase secrets set`, `preparar.sh` con la clave real y un endpoint de webhook en Stripe apuntando a `/functions/v1/stripe-webhook`.
- Producción (`gvasthxiqckmekwvhtrg`) no se toca al desarrollar: solo con la skill `subir-a-produccion` y confirmación del usuario. `vivo.py --produccion` conecta la app a producción; no usarlo para desarrollar.
