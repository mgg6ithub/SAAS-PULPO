// Borra la cuenta que la llama (DEV-018). Antes borra las empresas en las que es el único miembro, para no
// dejar datos huérfanos; en las demás solo desaparece como miembro (miembros y perfil caen en cascada).
// La sesión se comprueba aquí con el token del usuario; borrar en auth.users necesita la clave secreta.
const URL_BASE = Deno.env.get('SUPABASE_URL')!
const CLAVE = (JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>).default ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const responder = (estado: number, cuerpo: Record<string, unknown>) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: { ...CORS, 'Content-Type': 'application/json' } })

const admin = (ruta: string, init: RequestInit = {}) =>
  fetch(`${URL_BASE}${ruta}`, {
    ...init,
    headers: { apikey: CLAVE, Authorization: `Bearer ${CLAVE}`, 'Content-Type': 'application/json', ...init.headers },
  })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return responder(405, { error: 'Solo POST' })

  // ¿Quién llama? El token del usuario lo valida Auth.
  const token = req.headers.get('Authorization')?.replace(/^Bearer /, '') ?? ''
  const yo = await fetch(`${URL_BASE}/auth/v1/user`, { headers: { apikey: CLAVE, Authorization: `Bearer ${token}` } })
  if (!yo.ok) return responder(401, { error: 'Sin sesión' })
  const { id } = await yo.json() as { id: string }

  // Empresas donde es el único miembro: se borran enteras (todo lo suyo cae en cascada).
  const mias = await (await admin(`/rest/v1/miembros?usuario_id=eq.${id}&select=empresa_id`)).json() as
    { empresa_id: string }[]
  for (const { empresa_id } of mias) {
    const todos = await (await admin(`/rest/v1/miembros?empresa_id=eq.${empresa_id}&select=usuario_id`)).json() as
      unknown[]
    if (todos.length === 1) {
      const r = await admin(`/rest/v1/empresas?id=eq.${empresa_id}`, { method: 'DELETE' })
      if (!r.ok) return responder(500, { error: `No se pudo borrar la empresa: ${await r.text()}` })
    }
  }

  const r = await admin(`/auth/v1/admin/users/${id}`, { method: 'DELETE' })
  if (!r.ok) return responder(500, { error: `No se pudo borrar la cuenta: ${await r.text()}` })
  return responder(200, { ok: true })
})
