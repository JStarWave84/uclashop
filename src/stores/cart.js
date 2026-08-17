import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

export const useCartStore = defineStore(
  'cart',
  () => {
    const items = ref([])
    const drawerOpen = ref(false)
    const sessionProductIds = ref([])
    const hasOpenSession = ref(false)

    let jornadaPromise = null

    function loadJornadaProducts() {
      if (!jornadaPromise) {
        jornadaPromise = (async () => {
          const { data: sessions } = await supabase
            .from('sales_sessions')
            .select('id')
            .eq('is_open', true)
            .limit(1)
          if (sessions && sessions.length > 0) {
            const { data: ps } = await supabase
              .from('product_sessions')
              .select('product_id')
              .eq('session_id', sessions[0].id)
            sessionProductIds.value = (ps || []).map((r) => r.product_id)
            hasOpenSession.value = true
          }
        })()
      }
      return jornadaPromise
    }

    function isJornadaProduct(id) {
      return sessionProductIds.value.includes(id)
    }

    const isJornadaCart = computed(
      () =>
        items.value.length > 0 &&
        hasOpenSession.value &&
        items.value.every((i) => sessionProductIds.value.includes(i.id))
    )

    function openDrawer() {
      drawerOpen.value = true
    }

    function closeDrawer() {
      drawerOpen.value = false
    }

    function toggleDrawer() {
      drawerOpen.value = !drawerOpen.value
    }

    async function addItem(product, qty = 1) {
      if (!product || !product.id) {
        // ignore invalid
        return false
      }
      await loadJornadaProducts()

      if (items.value.length > 0) {
        const newIsJornada = isJornadaProduct(product.id)
        const cartIsJornada = items.value.every((i) => isJornadaProduct(i.id))
        if (newIsJornada !== cartIsJornada) {
          toast.error(
            'No podés mezclar productos de la jornada con productos del catálogo. Eliminá los del carrito para cambiar.'
          )
          return false
        }
      }

      const existing = items.value.find((i) => i.id === product.id)
      if (existing) {
        existing.quantity += qty
      } else {
        items.value.push({ ...product, quantity: qty })
      }
      openDrawer()
      return true
    }

    function removeItem(id) {
      items.value = items.value.filter((i) => i.id !== id)
    }

    function updateQty(id, qty) {
      const it = items.value.find((i) => i.id === id)
      if (it) it.quantity = qty
    }

    function clearCart() {
      items.value = []
    }

    const totalCount = computed(() => items.value.reduce((s, i) => s + (i.quantity || 0), 0))
    const totalPrice = computed(() =>
      items.value.reduce((s, i) => s + (i.quantity || 0) * (i.price || 0), 0)
    )

    return {
      items,
      drawerOpen,
      sessionProductIds,
      hasOpenSession,
      loadJornadaProducts,
      isJornadaProduct,
      isJornadaCart,
      addItem,
      removeItem,
      updateQty,
      clearCart,
      openDrawer,
      closeDrawer,
      toggleDrawer,
      totalCount,
      totalPrice,
    }
  },
  {
    persist: { pick: ['items'] },
  }
)