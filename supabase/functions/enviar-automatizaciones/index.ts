// Manda los emails pendientes de envios_automatizacion por SMTP (el servidor que quieras: el del dominio, Gmail,
// uno propio…). La llama el cron de la base cada 5 minutos con el secreto compartido en `x-cron-secret`.
// Sin SMTP_HOST no envía nada: los marca `simulado`.
//
// Secretos de la función: CRON_SECRET (el mismo que está en Vault) y, para enviar de verdad,
// SMTP_HOST, SMTP_PORT (465 = TLS directo, 587 = STARTTLS), SMTP_USER, SMTP_PASS y MAIL_FROM.
import nodemailer from 'npm:nodemailer@6.9.16'

const URL_BASE = Deno.env.get('SUPABASE_URL')!
const CLAVE = (JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>).default ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const MAX_INTENTOS = 3
const REINTENTO_RECLAMO_MIN = 10

const smtp = Deno.env.get('SMTP_HOST')
  ? nodemailer.createTransport({
    host: Deno.env.get('SMTP_HOST'),
    port: Number(Deno.env.get('SMTP_PORT') ?? 587),
    secure: Number(Deno.env.get('SMTP_PORT') ?? 587) === 465,
    auth: { user: Deno.env.get('SMTP_USER'), pass: Deno.env.get('SMTP_PASS') },
  })
  : null
const DESDE = Deno.env.get('MAIL_FROM') ?? Deno.env.get('SMTP_USER') ?? 'Pultec <no-reply@localhost>'
// La dirección real es siempre la de la cuenta; el nombre que se ve cambia por empresa («Pultec · Empresa»).
const DIRECCION = DESDE.match(/<([^>]+)>/)?.[1] ?? DESDE.match(/\S+@\S+/)?.[0] ?? DESDE

type Envio = {
  id: string
  destinatario: string
  asunto: string
  cuerpo: string
  intentos: number
  remitente: string
  responder_a: string | null
}

const rest = (ruta: string, init: RequestInit = {}) =>
  fetch(`${URL_BASE}/rest/v1/${ruta}`, {
    ...init,
    headers: { apikey: CLAVE, 'Content-Type': 'application/json', Prefer: 'return=minimal', ...init.headers },
  })

const marcar = (id: string, cambios: Record<string, unknown>) =>
  rest(`envios_automatizacion?id=eq.${id}`, { method: 'PATCH', body: JSON.stringify(cambios) })

/** Se queda con la fila si nadie la ha reclamado antes (la actualización solo cambia una fila si sigue libre). */
async function reclamar(id: string): Promise<boolean> {
  const caducado = new Date(Date.now() - REINTENTO_RECLAMO_MIN * 60_000).toISOString()
  const r = await rest(
    `envios_automatizacion?id=eq.${id}&or=(estado.in.(pendiente,error),and(estado.eq.enviando,reclamado_en.lt.${caducado}))`,
    {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify({ estado: 'enviando', reclamado_en: new Date().toISOString() }),
    },
  )
  return r.ok && ((await r.json()) as unknown[]).length === 1
}

const escapar = (t: string) =>
  t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;')

/** La misma carta en HTML sencillo (Gmail desconfía de los emails solo de texto): párrafos y la firma en gris. */
function html(cuerpo: string): string {
  const [texto, firma] = cuerpo.split('\n-- \n')
  const parrafos = texto.trim().split(/\n{2,}/).map((p) => `<p>${escapar(p).replaceAll('\n', '<br>')}</p>`).join('')
  const pie = firma
    ? `<p style="color:#6b7280;font-size:13px">${escapar(firma.trim()).replaceAll('\n', '<br>')}</p>`
    : ''
  return `<!doctype html><html lang="es"><body style="font-family:Arial,sans-serif;font-size:15px;color:#111827">` +
    `${parrafos}${pie}</body></html>`
}

// Dominios reservados de las pruebas (`ana@prueba.invalid`): nunca salen, así no rebotan en la cuenta de Pultec.
const DE_PRUEBA = /\.(invalid|test|example|localhost)$/i

async function enviar(e: Envio): Promise<void> {
  if (!smtp || DE_PRUEBA.test(e.destinatario)) {
    await marcar(e.id, { estado: 'simulado', enviado_en: new Date().toISOString() })
    return
  }
  try {
    await smtp.sendMail({
      from: { name: e.remitente, address: DIRECCION },
      replyTo: e.responder_a ?? undefined,
      to: e.destinatario,
      subject: e.asunto,
      text: e.cuerpo,
      html: html(e.cuerpo),
      // Sin esto nodemailer firma el Message-ID con el nombre de la máquina de la función (señal de spam).
      messageId: `<${e.id}@${DIRECCION.split('@')[1] ?? 'pultec'}>`,
    })
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
  const caducado = new Date(Date.now() - REINTENTO_RECLAMO_MIN * 60_000).toISOString()
  const r = await rest(
    `envios_automatizacion?intentos=lt.${MAX_INTENTOS}` +
      `&or=(estado.in.(pendiente,error),and(estado.eq.enviando,reclamado_en.lt.${caducado}))` +
      '&order=created_at&limit=50&select=id,destinatario,asunto,cuerpo,intentos,remitente,responder_a',
    { headers: { Prefer: '' } },
  )
  if (!r.ok) return new Response(`No se pudo leer la cola: ${r.status}`, { status: 500 })
  const candidatos = (await r.json()) as Envio[]
  let enviados = 0
  for (const e of candidatos) {
    if (!(await reclamar(e.id))) continue
    await enviar(e)
    enviados++
  }
  return Response.json({ procesados: enviados, modo: smtp ? 'smtp' : 'simulado' })
})
