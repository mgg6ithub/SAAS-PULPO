// Manda al cliente el PDF del parte de trabajo (DEV-029). La app lo genera y lo envía en base64 al guardar el
// parte; aquí se comprueba con el token del usuario que puede ver ese informe y se manda una sola vez por SMTP.
//
// Secretos: los mismos SMTP_* y MAIL_FROM que «enviar-automatizaciones».
import nodemailer from 'npm:nodemailer@6.9.16'

const URL_BASE = Deno.env.get('SUPABASE_URL')!
const CLAVE = (JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>).default ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const PUBLICABLE = (JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>).default ??
  Deno.env.get('SUPABASE_ANON_KEY')!

const smtp = Deno.env.get('SMTP_HOST')
  ? nodemailer.createTransport({
    host: Deno.env.get('SMTP_HOST'),
    port: Number(Deno.env.get('SMTP_PORT') ?? 587),
    secure: Number(Deno.env.get('SMTP_PORT') ?? 587) === 465,
    auth: { user: Deno.env.get('SMTP_USER'), pass: Deno.env.get('SMTP_PASS') },
  })
  : null
const DESDE = Deno.env.get('MAIL_FROM') ?? Deno.env.get('SMTP_USER') ?? 'Pultec <no-reply@localhost>'
const DIRECCION = DESDE.match(/<([^>]+)>/)?.[1] ?? DESDE.match(/\S+@\S+/)?.[0] ?? DESDE
const DE_PRUEBA = /\.(invalid|test|example|localhost)$/i

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const responder = (estado: number, cuerpo: Record<string, unknown>) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...CORS, 'Content-Type': 'application/json' } })

type Informe = {
  id: string
  created_at: string
  parte_enviado_en: string | null
  trabajos: { nombre: string; clientes: { nombre: string; email: string } | null }
  empresas: { nombre: string; creada_por: string }
}

const fecha = (iso: string) =>
  new Date(iso).toLocaleDateString('es-ES', { timeZone: 'Europe/Madrid', day: '2-digit', month: '2-digit', year: 'numeric' })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return responder(405, { error: 'Solo POST' })
  const { informe_id, pdf } = await req.json().catch(() => ({})) as { informe_id?: string; pdf?: string }
  if (!informe_id || !pdf) return responder(400, { error: 'Faltan informe_id y pdf' })

  // ¿Puede quien llama ver este informe? Se pregunta con su token: si las políticas no le dejan, no existe.
  const puede = await fetch(`${URL_BASE}/rest/v1/informes?id=eq.${encodeURIComponent(informe_id)}&select=id`, {
    headers: { apikey: PUBLICABLE, Authorization: req.headers.get('Authorization') ?? '' },
  })
  if (!puede.ok) return responder(401, { error: 'Sin sesión' })
  if (((await puede.json()) as unknown[]).length !== 1) return responder(404, { error: 'No existe el informe' })

  const admin = (ruta: string, init: RequestInit = {}) =>
    fetch(`${URL_BASE}${ruta}`, {
      ...init,
      headers: { apikey: CLAVE, 'Content-Type': 'application/json', Prefer: 'return=representation', ...init.headers },
    })
  // Los datos, con la clave secreta: el trabajador puede no ver la ficha del cliente.
  const [i] = await (await admin(
    `/rest/v1/informes?id=eq.${encodeURIComponent(informe_id)}` +
      '&select=id,created_at,parte_enviado_en,trabajos(nombre,clientes(nombre,email)),empresas(nombre,creada_por)',
  )).json() as Informe[]
  if (i.parte_enviado_en) return responder(200, { enviado: false, motivo: 'ya enviado' })
  const correo = i.trabajos.clientes?.email?.trim().toLowerCase() ?? ''
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(correo)) return responder(200, { enviado: false, motivo: 'cliente sin correo' })
  if (!smtp || DE_PRUEBA.test(correo)) return responder(200, { enviado: false, motivo: 'simulado' })

  // Reclamar el envío: solo una llamada cambia la fila mientras siga sin enviar.
  const marcar = (cambios: Record<string, unknown>, condicion = '') =>
    admin(`/rest/v1/informes?id=eq.${i.id}${condicion}`, { method: 'PATCH', body: JSON.stringify(cambios) })
  const reclamo = await marcar({ parte_enviado_en: new Date().toISOString(), parte_enviado_a: correo }, '&parte_enviado_en=is.null')
  if (!reclamo.ok || ((await reclamo.json()) as unknown[]).length !== 1) {
    return responder(200, { enviado: false, motivo: 'ya enviado' })
  }

  // «Responder a»: el administrador que creó la empresa.
  const yo = await admin(`/auth/v1/admin/users/${i.empresas.creada_por}`)
  const responderA = yo.ok ? ((await yo.json()) as { email?: string }).email : undefined
  const empresa = i.empresas.nombre.trim()
  const cliente = i.trabajos.clientes?.nombre ?? ''
  const dia = fecha(i.created_at)
  try {
    await smtp.sendMail({
      from: { name: empresa ? `Pultec · ${empresa}` : 'Pultec', address: DIRECCION },
      replyTo: responderA,
      to: correo,
      subject: `Parte de trabajo: ${i.trabajos.nombre} (${dia})`,
      text: `Hola${cliente ? ` ${cliente}` : ''}:\n\nTe adjuntamos el parte del trabajo «${i.trabajos.nombre}» del ${dia}.` +
        `\n\n—\nEnviado por Pultec${empresa ? ` · ${empresa}` : ''}`,
      attachments: [{
        filename: `Parte ${i.trabajos.nombre} ${dia.replaceAll('/', '-')}.pdf`,
        content: pdf,
        encoding: 'base64',
        contentType: 'application/pdf',
      }],
    })
  } catch (err) {
    await marcar({ parte_enviado_en: null, parte_enviado_a: null })
    return responder(502, { error: String(err).slice(0, 300) })
  }
  return responder(200, { enviado: true, a: correo })
})
