// Manda los emails pendientes de envios_automatizacion. La llama el cron de la base cada 5 minutos con
// el secreto compartido en `x-cron-secret`. Sin RESEND_API_KEY no envía nada: los marca `simulado`.
//
// Secretos de la función: CRON_SECRET (el mismo que está en Vault), RESEND_API_KEY y MAIL_FROM (opcionales).

const URL_BASE = Deno.env.get('SUPABASE_URL')!
const CLAVE = (JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>).default ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND = Deno.env.get('RESEND_API_KEY')
const DESDE = Deno.env.get('MAIL_FROM') ?? 'Pultec <onboarding@resend.dev>'
const MAX_INTENTOS = 3

type Envio = { id: string; destinatario: string; asunto: string; cuerpo: string; intentos: number }

const rest = (ruta: string, init: RequestInit = {}) =>
  fetch(`${URL_BASE}/rest/v1/${ruta}`, {
    ...init,
    headers: { apikey: CLAVE, 'Content-Type': 'application/json', Prefer: 'return=minimal', ...init.headers },
  })

const marcar = (id: string, cambios: Record<string, unknown>) =>
  rest(`envios_automatizacion?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(cambios) })

async function enviar(e: Envio): Promise<void> {
  if (!RESEND) {
    await marcar(e.id, { estado: 'simulado', enviado_en: new Date().toISOString() })
    return
  }
  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${RESEND}`,
        'Content-Type': 'application/json',
        // Si la función se ejecuta dos veces a la vez, Resend no manda el mismo email dos veces.
        'Idempotency-Key': e.id,
      },
      body: JSON.stringify({ from: DESDE, to: [e.destinatario], subject: e.asunto, text: e.cuerpo }),
    })
    if (!r.ok) throw new Error(`Resend ${r.status}: ${(await r.text()).slice(0, 300)}`)
    await marcar(e.id, { estado: 'enviado', enviado_en: new Date().toISOString(), error: null })
  } catch (err) {
    await marcar(e.id, { estado: 'error', intentos: e.intentos + 1, error: String(err).slice(0, 500) })
  }
}

Deno.serve(async (req) => {
  const secreto = Deno.env.get('CRON_SECRET')
  if (!secreto || req.headers.get('x-cron-secret') !== secreto) {
    return new Response('No autorizado', { status: 401 })
  }
  const r = await rest(
    `envios_automatizacion?estado=in.(pendiente,error)&intentos=lt.${MAX_INTENTOS}&order=created_at&limit=50` +
      '&select=id,destinatario,asunto,cuerpo,intentos',
    { headers: { Prefer: '' } },
  )
  if (!r.ok) return new Response(`No se pudo leer la cola: ${r.status}`, { status: 500 })
  const pendientes = (await r.json()) as Envio[]
  for (const e of pendientes) await enviar(e)
  return Response.json({ procesados: pendientes.length, modo: RESEND ? 'real' : 'simulado' })
})
