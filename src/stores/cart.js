import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useCartStore = defineStore(
  'cart',
  () => {
    const items = ref([])

    function addItem(product, qty = 1) {
      if (!product || !product.id) {
        // ignore invalid
        return
      }
      const existing = items.value.find((i) => i.id === product.id)
      if (existing) {
        existing.quantity += qty
      } else {
        items.value.push({ ...product, quantity: qty })
      }
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

    return { items, addItem, removeItem, updateQty, clearCart, totalCount, totalPrice }
  },
  {
    persist: true,
  }
)
