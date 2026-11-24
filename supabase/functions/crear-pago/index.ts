// Abre el pago de Premium en Stripe (Checkout) para una empresa. Solo su admin. Devuelve { url } y la app
// redirige ahí; al terminar, Stripe vuelve a `volver` con ?pago=ok o ?pago=cancelado.
// Aquí NO se activa nada: el plan lo activa stripe-webhook cuando Stripe confirma el cobro.
// Cuerpo: { empresa_id, periodo: 'mensual' | 'anual', volver }
import { ACTIVA, CORS, esAdmin, guardarSuscripcion, responder, stripe, suscripcionDe, usuario, volverA, admin } from '../_shared/pagos.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return responder(405, { error: 'Solo POST' })

  const yo = await usuario(req)
  if (!yo) return responder(401, { error: 'Sin sesión' })
  const { empresa_id, periodo, volver } = await req.json().catch(() => ({}))
  if (!await esAdmin(yo.id, empresa_id)) return responder(403, { error: 'Solo el administrador gestiona el plan' })
  if (periodo !== 'mensual' && periodo !== 'anual') return responder(400, { error: 'Periodo no válido' })
  const ok = volverA(volver, { pago: 'ok' }), cancelado = volverA(volver, { pago: 'cancelado' })
  if (!ok || !cancelado) return responder(400, { error: 'Dirección de vuelta no permitida' })

  try {
    const s = await suscripcionDe(empresa_id)
    // Ya paga: no se abre otra suscripción (sería cobrar dos veces). La app abre el portal en su lugar.
    if (s?.plan === 'premium' && ACTIVA.includes(s.estado ?? '')) return responder(409, { error: 'ya_premium' })

    // Cliente de Stripe = la empresa. Se crea una vez y se reutiliza (facturas, tarjetas, historial).
    let cliente = s?.stripe_customer_id
    if (!cliente) {
      const [empresa] = await (await admin(`/rest/v1/empresas?id=eq.${empresa_id}&select=nombre`)).json()
      const c = await stripe<{ id: string }>('customers', [
        ['email', yo.email],
        ['name', empresa?.nombre || yo.email],
        ['preferred_locales[0]', 'es'],
        ['metadata[empresa_id]', empresa_id],
      ], { idempotencia: `cliente-${empresa_id}` }) // dos clics seguidos no crean dos clientes
      cliente = c.id
      await guardarSuscripcion({ empresa_id, stripe_customer_id: cliente })
    }

    const [precio] = (await stripe<{ data: { id: string }[] }>(
      `prices?active=true&lookup_keys[]=pultec_premium_${periodo}`,
    )).data
    if (!precio) throw new Error(`Falta el precio pultec_premium_${periodo} (supabase/stripe/preparar.sh)`)
    const iva = (await stripe<{ data: { id: string; metadata: Record<string, string> }[] }>('tax_rates?active=true&limit=100'))
      .data.find((t) => t.metadata?.clave === 'pultec_iva21')

    const sesion = await stripe<{ url: string }>('checkout/sessions', [
      ['mode', 'subscription'],
      ['customer', cliente],
      ['client_reference_id', empresa_id],
      ['line_items[0][price]', precio.id],
      ['line_items[0][quantity]', '1'],
      ...(iva ? [['line_items[0][tax_rates][0]', iva.id] as [string, string]] : []),
      ['subscription_data[metadata][empresa_id]', empresa_id],
      ['metadata[empresa_id]', empresa_id],
      ['success_url', ok],
      ['cancel_url', cancelado],
      ['locale', 'es'],
      // Factura a nombre de la empresa: dirección y NIF/CIF.
      ['billing_address_collection', 'required'],
      ['tax_id_collection[enabled]', 'true'],
      ['customer_update[name]', 'auto'],
      ['customer_update[address]', 'auto'],
      ['allow_promotion_codes', 'true'],
    ])
    return responder(200, { url: sesion.url })
  } catch (e) {
    console.error(e)
    return responder(500, { error: 'No se pudo abrir el pago. Vuelve a intentarlo en un momento.' })
  }
})
