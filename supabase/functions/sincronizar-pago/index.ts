// Pone al día el plan de una empresa preguntando a Stripe. La app la llama al volver del pago (?pago=ok) o del
// portal: así el Premium se ve al momento sin esperar al webhook. Cualquier miembro puede pedirlo (solo lee de
// Stripe y escribe lo que Stripe diga). Devuelve el plan vigente.
// Cuerpo: { empresa_id }
import { ACTIVA, CORS, admin, responder, sincronizarCliente, suscripcionDe, usuario } from '../_shared/pagos.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return responder(405, { error: 'Solo POST' })

  const yo = await usuario(req)
  if (!yo) return responder(401, { error: 'Sin sesión' })
  const { empresa_id } = await req.json().catch(() => ({}))
  if (!/^[0-9a-f-]{36}$/i.test(empresa_id ?? '')) return responder(400, { error: 'Empresa no válida' })
  const miembro = await (await admin(`/rest/v1/miembros?usuario_id=eq.${yo.id}&empresa_id=eq.${empresa_id}&select=rol`)).json()
  if (!miembro.length) return responder(403, { error: 'No eres de esta empresa' })

  try {
    const s = await suscripcionDe(empresa_id)
    if (s?.stripe_customer_id) await sincronizarCliente(s.stripe_customer_id)
    const despues = await suscripcionDe(empresa_id)
    const premium = despues?.plan === 'premium' && ACTIVA.includes(despues.estado ?? '')
    return responder(200, { plan: premium ? 'premium' : 'basico', estado: despues?.estado ?? null })
  } catch (e) {
    console.error(e)
    return responder(500, { error: 'No se pudo comprobar el plan' })
  }
})
