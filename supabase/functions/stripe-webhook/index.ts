// Avisos de Stripe (webhook): mantienen el plan al día cuando el usuario no está delante (renovaciones,
// cobros fallidos, cancelaciones que vencen). Al volver de pagar o del portal, la app además llama a
// sincronizar-pago para no esperar al aviso.
// 1. Comprueba la firma (Stripe-Signature + STRIPE_WEBHOOK_SECRET): si no es de Stripe, 400.
// 2. No se fía del contenido del aviso: vuelve a pedir la suscripción a Stripe y copia su estado actual.
//    Así da igual que los avisos lleguen desordenados o repetidos (Stripe reintenta si no respondemos 200).
import { responder, sincronizar } from '../_shared/pagos.ts'

const SECRETO = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
const TOLERANCIA_S = 300

async function firmaValida(cuerpo: string, cabecera: string | null): Promise<boolean> {
  if (!cabecera || !SECRETO) return false
  const partes = cabecera.split(',').map((p) => p.split('=') as [string, string])
  const t = partes.find(([k]) => k === 't')?.[1]
  const firmas = partes.filter(([k]) => k === 'v1').map(([, v]) => v)
  if (!t || !firmas.length || Math.abs(Date.now() / 1000 - Number(t)) > TOLERANCIA_S) return false
  const clave = await crypto.subtle.importKey('raw', new TextEncoder().encode(SECRETO), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', clave, new TextEncoder().encode(`${t}.${cuerpo}`)))
  const esperada = Array.from(mac, (b) => b.toString(16).padStart(2, '0')).join('')
  // Comparación en tiempo constante.
  return firmas.some((f) => f.length === esperada.length && [...f].reduce((d, c, i) => d | (c.charCodeAt(0) ^ esperada.charCodeAt(i)), 0) === 0)
}

/** De qué suscripción habla el aviso (según el tipo y la versión de la API, está en un sitio u otro). */
// deno-lint-ignore no-explicit-any
function suscripcionDelAviso(tipo: string, o: Record<string, any>): string | null {
  if (tipo.startsWith('customer.subscription.')) return o.id
  if (tipo === 'checkout.session.completed') return o.mode === 'subscription' ? o.subscription : null
  if (tipo.startsWith('invoice.')) return o.subscription ?? o.parent?.subscription_details?.subscription ?? null
  return null
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return responder(405, { error: 'Solo POST' })
  const cuerpo = await req.text()
  if (!await firmaValida(cuerpo, req.headers.get('Stripe-Signature'))) return responder(400, { error: 'Firma no válida' })

  const aviso = JSON.parse(cuerpo) as { type: string; data: { object: Record<string, unknown> } }
  const subId = suscripcionDelAviso(aviso.type, aviso.data.object)
  if (!subId) return responder(200, { ignorado: aviso.type })
  try {
    await sincronizar(subId)
    return responder(200, { ok: true })
  } catch (e) {
    console.error(e)
    return responder(500, { error: 'reintentar' }) // Stripe lo vuelve a mandar más tarde
  }
})
