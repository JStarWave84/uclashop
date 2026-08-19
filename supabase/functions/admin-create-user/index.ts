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

    const { email, password, full_name, store_id, role_in_store, role } = await req.json()

    if (!email || !password) {
      return json({ error: 'Correo y contraseña son obligatorios' }, 400)
    }

    if (role !== undefined && role !== null && !['store', 'admin'].includes(role)) {
      return json({ error: 'Rol inválido' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    })

    const { data: identity, error: identityError } = await userClient.auth.getUser(token)
    if (identityError || !identity.user) {
      return json({ error: 'No autorizado' }, 401)
    }

    const { data: profile } = await serviceClient
      .from('profiles')
      .select('role')
      .eq('id', identity.user.id)
      .single()

    if (!profile || profile.role !== 'admin') {
      return json({ error: 'Solo un administrador puede crear usuarios' }, 403)
    }

    const { data: created, error: createError } = await serviceClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: full_name ? { full_name } : undefined,
    })

    if (createError) {
      const status = createError.message?.toLowerCase().includes('already registered') ? 409 : 400
      return json({ error: createError.message || 'No se pudo crear el usuario' }, status)
    }

    const userId = created.user.id

    // Sistema: asignar rol del sistema si se pidió. Para 'admin' usamos la RPC
    // admin_update_user_profile con el JWT del llamador (userClient) para que
    // el trigger protect_profile_role vea auth.uid() del admin y permita la
    // asignación; para 'store' alcanza con un update directo vía service role.
    if (role === 'admin') {
      const { error: roleError } = await userClient.rpc('admin_update_user_profile', {
        p_user_id: userId,
        p_role: 'admin',
        p_set_role: true,
      })
      if (roleError) {
        return json({ error: roleError.message || 'No se pudo asignar el rol' }, 400)
      }
    } else if (role === 'store') {
      const { error: roleError } = await serviceClient
        .from('profiles')
        .update({ role: 'store' })
        .eq('id', userId)
      if (roleError) {
        return json({ error: roleError.message || 'No se pudo asignar el rol' }, 400)
      }
    }

    if (store_id) {
      const membershipError = await assignToStore(serviceClient, userId, store_id, role_in_store)
      if (membershipError) {
        return json({ error: membershipError, user_id: userId }, 409)
      }
    }

    return json({ user_id: userId, email }, 200)
  } catch (err) {
    return json({ error: err instanceof Error ? err.message : 'Error interno' }, 500)
  }
})

async function assignToStore(client, userId, storeId, roleInStore) {
  const role = roleInStore === 'owner' ? 'owner' : 'staff'

  const { data: store } = await client.from('stores').select('id').eq('id', storeId).maybeSingle()
  if (!store) return 'La tienda no existe'

  const { data: existing } = await client
    .from('store_members')
    .select('store_id')
    .eq('user_id', userId)
    .maybeSingle()
  if (existing) return 'Ese usuario ya pertenece a una tienda'

  const { error: insertError } = await client.from('store_members').insert({
    store_id: storeId,
    user_id: userId,
    role_in_store: role,
  })
  if (insertError) return insertError.message

  await client.from('profiles').update({ role: 'store' }).eq('id', userId).is('role', null)

  return null
}

function json(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}