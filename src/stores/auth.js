import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabaseClient'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const loading = ref(true)

  const isAuthenticated = computed(() => !!user.value)
  const userEmail = computed(() => user.value?.email || '')
  const userName = computed(
    () => user.value?.user_metadata?.full_name || user.value?.email?.split('@')[0] || 'Admin'
  )

  async function fetchSession() {
    loading.value = true
    const {
      data: { session },
    } = await supabase.auth.getSession()
    user.value = session?.user ?? null
    loading.value = false
  }

  function setSession(session) {
    user.value = session?.user ?? null
  }

  async function signOut() {
    const { error } = await supabase.auth.signOut()
    if (error) console.error('signOut', error)
    user.value = null
  }

  // Listen to auth changes
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
      setSession(session)
    } else if (event === 'SIGNED_OUT') {
      user.value = null
    }
  })

  return { user, loading, isAuthenticated, userEmail, userName, fetchSession, signOut }
})
