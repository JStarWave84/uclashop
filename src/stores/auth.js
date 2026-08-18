import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabaseClient'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const profile = ref(null)
  const store = ref(null)
  const loading = ref(true)

  const isAuthenticated = computed(() => !!user.value)
  const role = computed(() => profile.value?.role || null)
  const isAdmin = computed(() => role.value === 'admin')
  const isStoreUser = computed(() => role.value === 'store')
  const storeId = computed(() => store.value?.id || null)
  const isVerifiedStore = computed(() => !!store.value?.is_verified)
  const userEmail = computed(() => user.value?.email || '')
  const userName = computed(
    () => profile.value?.full_name || user.value?.user_metadata?.full_name || user.value?.email?.split('@')[0] || 'Admin'
  )

  async function fetchProfile() {
    if (!user.value) {
      profile.value = null
      store.value = null
      return
    }
    const { data: prof, error } = await supabase.from('profiles').select('*').eq('id', user.value.id).single()
    if (error) {
      console.error('fetchProfile', error)
      profile.value = null
    } else {
      profile.value = prof
    }

    const { data: sm } = await supabase.from('store_members').select('store_id').eq('user_id', user.value.id).maybeSingle()
    if (sm?.store_id) {
      const { data: st, error: stErr } = await supabase.from('stores').select('*').eq('id', sm.store_id).single()
      if (stErr) console.error('fetchStore', stErr)
      store.value = st ?? null
    } else {
      store.value = null
    }
  }

  async function fetchSession() {
    loading.value = true
    const {
      data: { session },
    } = await supabase.auth.getSession()
    user.value = session?.user ?? null
    await fetchProfile()
    loading.value = false
  }

  function setSession(session) {
    user.value = session?.user ?? null
    if (session?.user) fetchProfile()
    else {
      profile.value = null
      store.value = null
    }
  }

  async function signOut() {
    const { error } = await supabase.auth.signOut()
    if (error) console.error('signOut', error)
    user.value = null
    profile.value = null
    store.value = null
  }

  // Listen to auth changes
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
      setSession(session)
    } else if (event === 'SIGNED_OUT') {
      user.value = null
      profile.value = null
      store.value = null
    }
  })

  return {
    user,
    profile,
    store,
    loading,
    isAuthenticated,
    role,
    isAdmin,
    isStoreUser,
    storeId,
    isVerifiedStore,
    userEmail,
    userName,
    fetchSession,
    signOut,
  }
})