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

    // Un admin no puede eliminar su propia cuenta
    if (identity.user.id === user_id) {
      return json({ error: 'No podés eliminar tu propia cuenta' }, 400)
    }

    // No se puede eliminar al último administrador del sistema
    const { data: targetProfile } = await serviceClient
      .from('profiles')
      .select('role')
      .eq('id', user_id)
      .maybeSingle()

    if (targetProfile?.role === 'admin') {
      const { count } = await serviceClient
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .eq('role', 'admin')
      if ((count ?? 0) <= 1) {
        return json({ error: 'No se puede eliminar el último administrador' }, 400)
      }
    }

    // Eliminar la cuenta de auth. El perfil y las membresías se limpian solos
    // por ON DELETE CASCADE (profiles_auth_user_fk y store_members.user_id).
    const { error: deleteError } = await serviceClient.auth.admin.deleteUser(user_id)
    if (deleteError) {
      return json({ error: deleteError.message || 'No se pudo eliminar el usuario' }, 400)
    }

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