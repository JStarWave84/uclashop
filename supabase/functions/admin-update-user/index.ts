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

    const { user_id, full_name, email, password, role } = await req.json()

    if (!user_id) {
      return json({ error: 'user_id es obligatorio' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const serviceClient = createClient(supabaseUrl, serviceKey)

    // Cliente con el contexto del admin (JWT en Authorization) para que los
    // triggers de profiles (protect_profile_role) vean auth.uid() del admin.
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

    // Construimos el patch de perfil solo con lo que venga en el body
    const profilePatch: Record<string, any> = {}
    if (full_name !== undefined) profilePatch.full_name = full_name
    // Solo admin puede cambiar el role
    if (role !== undefined && profile?.role === 'admin') profilePatch.role = role || null

    // Verificación de permisos:
    // - Admin: puede editar cualquier usuario
    // - Usuario no-admin: solo puede editar su propio nombre (user_id debe coincidir con el del token)
    const isAdmin = profile?.role === 'admin'
    const isOwnUser = identity.user.id === user_id

    if (!isAdmin && !isOwnUser) {
      return json({ error: 'No tienes permiso para editar este usuario' }, 403)
    }

    // Actualizar auth (email y/or password) si se proporcionaron
    const authUpdates: Record<string, any> = {}
    if (email) {
      authUpdates.email = email
      authUpdates.email_confirm = true
    }
    if (password) authUpdates.password = password

    if (Object.keys(authUpdates).length > 0) {
      const { error: authError } = await serviceClient.auth.admin.updateUserById(user_id, authUpdates)
      if (authError) {
        return json({ error: authError.message || 'No se pudo actualizar el usuario' }, 400)
      }
    }

    // Actualizar perfil
    if (Object.keys(profilePatch).length > 0) {
      const { error: profileError } = await adminContextClient
        .from('profiles')
        .update(profilePatch)
        .eq('id', user_id)
      if (profileError) {
        return json({ error: profileError.message || 'No se pudo actualizar el perfil' }, 400)
      }
    }

    return json({ ok: true }, 200)
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