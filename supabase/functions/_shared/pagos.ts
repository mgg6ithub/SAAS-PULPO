// Común a las funciones de pago (crear-pago, portal-pago, stripe-webhook). Sin librerías: fetch a Supabase y a
// la API de Stripe, como el resto de funciones. Secretos: STRIPE_SECRET_KEY y STRIPE_WEBHOOK_SECRET
// (en local, supabase/.env vía `./entorno.sh funciones`; en producción, `supabase secrets set`).
const URL_BASE = Deno.env.get('SUPABASE_URL')!
const CLAVE = (JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>).default ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const STRIPE = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
// Versión fija de la API de Stripe: las respuestas no cambian de forma aunque Stripe saque versiones nuevas.
const STRIPE_VERSION = '2025-03-31.basil'

// Direcciones de la app a las que se puede volver tras pagar (nada de redirigir a sitios ajenos).
const ORIGENES = (Deno.env.get('APP_ORIGENES') ??
  'http://localhost:8000,http://127.0.0.1:8000,https://saas-pulpo.pages.dev').split(',')

export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export const responder = (estado: number, cuerpo: Record<string, unknown>) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...CORS, 'Content-Type': 'application/json' } })

/** Supabase con la clave secreta (se salta RLS: solo para lo que la app no puede hacer). */
export const admin = (ruta: string, init: RequestInit = {}) =>
  fetch(`${URL_BASE}${ruta}`, {
    ...init,
    headers: { apikey: CLAVE, 'Content-Type': 'application/json', ...init.headers },
  })

/** Quién llama, validando su token con Auth. */
export async function usuario(req: Request): Promise<{ id: string; email: string } | null> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer /, '') ?? ''
  const r = await fetch(`${URL_BASE}/auth/v1/user`, { headers: { apikey: CLAVE, Authorization: `Bearer ${token}` } })
  return r.ok ? await r.json() : null
}

/** ¿Es administrador de esa empresa? Solo el admin gestiona el plan. */
export async function esAdmin(usuarioId: string, empresaId: string): Promise<boolean> {
  if (!/^[0-9a-f-]{36}$/i.test(empresaId)) return false
  const r = await admin(`/rest/v1/miembros?usuario_id=eq.${usuarioId}&empresa_id=eq.${empresaId}&rol=eq.admin&select=rol`)
  return r.ok && (await r.json() as unknown[]).length > 0
}

export type Suscripcion = {
  empresa_id: string
  stripe_customer_id: string | null
  stripe_subscription_id: string | null
  plan: string
  estado: string | null
}

export async function suscripcionDe(empresaId: string): Promise<Suscripcion | null> {
  const r = await admin(`/rest/v1/suscripciones?empresa_id=eq.${empresaId}&select=*`)
  return ((await r.json()) as Suscripcion[])[0] ?? null
}

/** Crea o actualiza la fila de la empresa (upsert por empresa_id). */
export async function guardarSuscripcion(fila: Partial<Suscripcion> & { empresa_id: string } & Record<string, unknown>) {
  const r = await admin('/rest/v1/suscripciones?on_conflict=empresa_id', {
    method: 'POST',
    headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify(fila),
  })
  if (!r.ok) throw new Error(`No se pudo guardar la suscripción: ${await r.text()}`)
}

export const ACTIVA = ['active', 'trialing', 'past_due']

type Sub = {
  id: string
  status: string
  customer: string
  created: number
  cancel_at_period_end: boolean
  cancel_at: number | null
  current_period_end?: number
  metadata: Record<string, string>
  items: { data: { current_period_end?: number; price: { product: string; recurring: { interval: string } } }[] }
}

/** Copia a la base el estado ACTUAL de una suscripción, pidiéndolo a Stripe (nunca de lo que diga un aviso). */
export async function sincronizar(subId: string) {
  const sub = await stripe<Sub>(`subscriptions/${subId}`)
  let empresa = sub.metadata?.empresa_id
  if (!empresa) { // por si se creó a mano en Stripe: se busca por cliente
    const [f] = await (await admin(`/rest/v1/suscripciones?stripe_customer_id=eq.${sub.customer}&select=empresa_id`)).json()
    empresa = f?.empresa_id
  }
  if (!empresa) return console.warn(`Suscripción ${subId} sin empresa: se ignora`)

  // Un aviso viejo de otra suscripción ya terminada no pisa a la vigente.
  const actual = await suscripcionDe(empresa)
  if (actual?.stripe_subscription_id && actual.stripe_subscription_id !== sub.id &&
      ACTIVA.includes(actual.estado ?? '') && !ACTIVA.includes(sub.status)) {
    return console.warn(`Suscripción ${sub.id} (${sub.status}) ignorada: la vigente es ${actual.stripe_subscription_id}`)
  }

  const item = sub.items.data[0]
  const fin = sub.current_period_end ?? item?.current_period_end
  await guardarSuscripcion({
    empresa_id: empresa,
    stripe_customer_id: sub.customer,
    stripe_subscription_id: sub.id,
    plan: item?.price.product === 'pultec_premium' ? 'premium' : 'basico',
    periodo: item?.price.recurring.interval === 'year' ? 'anual' : 'mensual',
    estado: sub.status,
    fin_periodo: fin ? new Date(fin * 1000).toISOString() : null,
    cancela_al_final: sub.cancel_at_period_end || !!sub.cancel_at,
  })
  console.log(`Empresa ${empresa}: ${sub.status} (${sub.id})`)
}

/** Sincroniza la suscripción más relevante de un cliente: la activa si la hay; si no, la más reciente. */
export async function sincronizarCliente(cliente: string) {
  const { data } = await stripe<{ data: Sub[] }>(`subscriptions?customer=${cliente}&status=all&limit=10`)
  const elegida = data.find((s) => ACTIVA.includes(s.status)) ?? data.sort((a, b) => b.created - a.created)[0]
  if (elegida) await sincronizar(elegida.id)
}

/** Dirección de vuelta validada contra ORIGENES, con un parámetro añadido (p. ej. pago=ok). */
export function volverA(url: unknown, extra: Record<string, string> = {}): string | null {
  try {
    const u = new URL(String(url))
    if (!ORIGENES.some((o) => u.origin === new URL(o).origin)) return null
    u.hash = ''
    for (const [k, v] of Object.entries(extra)) u.searchParams.set(k, v)
    return u.toString()
  } catch {
    return null
  }
}

/** Llamada a la API de Stripe. Los parámetros van como formulario (a[b][0]=c), que es lo que espera Stripe. */
export async function stripe<T = Record<string, unknown>>(
  ruta: string,
  params?: [string, string][],
  opciones: { metodo?: string; idempotencia?: string } = {},
): Promise<T> {
  const metodo = opciones.metodo ?? (params ? 'POST' : 'GET')
  const r = await fetch(`https://api.stripe.com/v1/${ruta}`, {
    method: metodo,
    headers: {
      Authorization: `Bearer ${STRIPE}`,
      'Stripe-Version': STRIPE_VERSION,
      ...(params ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
      ...(opciones.idempotencia ? { 'Idempotency-Key': opciones.idempotencia } : {}),
    },
    body: params ? new URLSearchParams(params) : undefined,
  })
  const datos = await r.json()
  if (!r.ok) throw new Error(`Stripe ${ruta}: ${datos?.error?.message ?? r.status}`)
  return datos as T
}
