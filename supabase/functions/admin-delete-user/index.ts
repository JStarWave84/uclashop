import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Método no permitido' }, 405)
  }

  try {
    const authHeader = req.headers.get('Authorization') || ''
    const token = authHeader.replace(/^Bearer\s+/i, '')

    if (!token) {
      return json({ error: 'No autorizado' }, 401)
    }

    const { user_id } = await req.json()

    if (!user_id) {
      return json({ error: 'user_id es obligatorio' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const serviceClient = createClient(supabaseUrl, serviceKey)

    // Verificar que el llamador sea admin
    const adminContextClient = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    })

    const { data: identity } = await adminContextClient.auth.getUser(token)
    if (!identity?.user) {
      return json({ error: 'No autorizado' }, 401)
    }

    const { data: profile } = await serviceClient
      .from('profiles')
      .select('role')
      .eq('id', identity.user.id)
      .single()

    if (!profile || profile.role !== 'admin') {
      return json({ error: 'Solo un administrador puede eliminar usuarios' }, 403)
    }

    // Eliminar la cuenta de auth
    const { error: deleteError } = await serviceClient.auth.admin.deleteUser(user_id)
    if (deleteError) {
      return json({ error: deleteError.message || 'No se pudo eliminar el usuario' }, 400)
    }

    // Opcional: también eliminar el perfil y la membresía en store
    // (comentado para mantenerlo simple; si se necesita, descomentar abajo)
    /*
    await serviceClient.from('profiles').delete().eq('id', user_id)
    await serviceClient.from('store_members').delete().eq('user_id', user_id)
    */

    return json({ ok: true, message: 'Usuario eliminado' }, 200)
  } catch (err) {
    return json({ error: err instanceof Error ? err.message : 'Error interno' }, 500)
  }
})

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}