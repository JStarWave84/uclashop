import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY

// If env vars are missing, createClient will still work but requests will fail.
export const supabase = createClient(SUPABASE_URL || '', SUPABASE_ANON_KEY || '')

export default supabase

export async function signIn(email, password) {
  if (!email || !password) return { data: null, error: new Error('Email y contraseña requeridos') }
  try {
    const res = await supabase.auth.signInWithPassword({ email, password })
    return res
  } catch (error) {
    return { data: null, error }
  }
}

export async function resetPasswordForEmail(email) {
  if (!email) return { data: null, error: new Error('Email requerido') }
  try {
    const { origin } = window.location
    const res = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${origin}/auth/reset-password`,
    })
    return res
  } catch (error) {
    return { data: null, error }
  }
}

export async function updatePassword(newPassword) {
  if (!newPassword) return { data: null, error: new Error('Contraseña requerida') }
  try {
    const res = await supabase.auth.updateUser({ password: newPassword })
    return res
  } catch (error) {
    return { data: null, error }
  }
}
