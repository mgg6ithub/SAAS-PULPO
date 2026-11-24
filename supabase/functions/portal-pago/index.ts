// Abre el portal de cliente de Stripe de una empresa (cambiar tarjeta, mensual/anual, facturas, cancelar).
// Solo su admin. Devuelve { url }; al salir del portal, Stripe vuelve a `volver`.
// Cuerpo: { empresa_id, volver }
import { CORS, esAdmin, responder, stripe, suscripcionDe, usuario, volverA } from '../_shared/pagos.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return responder(405, { error: 'Solo POST' })

  const yo = await usuario(req)
  if (!yo) return responder(401, { error: 'Sin sesión' })
  const { empresa_id, volver } = await req.json().catch(() => ({}))
  if (!await esAdmin(yo.id, empresa_id)) return responder(403, { error: 'Solo el administrador gestiona el plan' })
  const vuelta = volverA(volver)
  if (!vuelta) return responder(400, { error: 'Dirección de vuelta no permitida' })

  try {
    const s = await suscripcionDe(empresa_id)
    if (!s?.stripe_customer_id) return responder(404, { error: 'sin_cliente' })
    const portal = await stripe<{ url: string }>('billing_portal/sessions', [
      ['customer', s.stripe_customer_id],
      ['return_url', vuelta],
      ['locale', 'es'],
    ])
    return responder(200, { url: portal.url })
  } catch (e) {
    console.error(e)
    return responder(500, { error: 'No se pudo abrir la gestión del plan. Vuelve a intentarlo en un momento.' })
  }
})
