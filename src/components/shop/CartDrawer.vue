<script setup>
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet'
import { Button } from '@/components/ui/button'
import { ShoppingCart, MessageCircle, ArrowRight } from '@lucide/vue'
import { useCartStore } from '@/stores/cart'
import { formatPrice } from '@/lib/utils'
import { resolveContactPhone, buildCartMessage, buildWhatsAppUrl } from '@/lib/whatsapp'
import CartItemRow from './CartItemRow.vue'

const cart = useCartStore()
const router = useRouter()

onMounted(() => {
  cart.loadJornadaProducts()
})

function goTo(path) {
  cart.closeDrawer()
  setTimeout(() => router.push(path), 300)
}

async function buyOnWhatsApp() {
  const phone = resolveContactPhone(cart.items)
  const message = buildCartMessage(cart.items, cart.totalPrice)
  window.open(buildWhatsAppUrl(phone, message), '_blank', 'noopener,noreferrer')
}
</script>

<template>
  <Sheet :open="cart.drawerOpen" @update:open="(v) => (cart.drawerOpen = v)">
    <SheetTrigger as-child>
      <button
        class="relative flex size-9 items-center justify-center rounded-lg text-ucla-700/70 transition-colors hover:bg-ucla-50 hover:text-ucla-600"
        aria-label="Carrito de compras"
      >
        <ShoppingCart class="size-5" />
        <span
          v-if="cart.totalCount > 0"
          class="absolute -right-1 -top-1 flex size-4 min-w-4 items-center justify-center rounded-full bg-ucla-gold px-1 text-[10px] font-bold leading-none text-white"
        >
          {{ cart.totalCount }}
        </span>
      </button>
    </SheetTrigger>

    <SheetContent side="right" class="flex w-full flex-col p-0 sm:max-w-md">
      <SheetHeader class="border-b border-ucla-100 px-4 py-4">
        <SheetTitle class="text-left text-base" style="font-family: var(--font-display)">
          Carrito de compras
        </SheetTitle>
      </SheetHeader>

      <div
        v-if="cart.items.length === 0"
        class="flex flex-1 flex-col items-center justify-center gap-3 px-6"
      >
        <ShoppingCart class="size-10 text-ucla-900/20" />
        <p class="text-sm text-ucla-900/40">Tu carrito está vacío</p>
        <Button variant="outline" size="sm" @click="goTo('/productos')">
          Explorar productos
        </Button>
      </div>

      <div v-else class="flex-1 overflow-y-auto px-4">
        <CartItemRow v-for="item in cart.items" :key="item.id" :item="item" compact />
      </div>

      <div v-if="cart.items.length > 0" class="border-t border-ucla-100 p-4">
        <div class="flex items-baseline justify-between">
          <span class="text-sm text-ucla-900/50">Total</span>
          <span class="text-xl font-semibold text-ucla-700 tabular-nums">
            {{ formatPrice(cart.totalPrice) }}
          </span>
        </div>
        <Button v-if="cart.isJornadaCart" @click="goTo('/checkout')" class="mt-4 w-full">
          Proceder al pago
          <ArrowRight class="size-4" />
        </Button>
        <Button v-else @click="buyOnWhatsApp" class="mt-4 w-full">
          <MessageCircle class="size-4" />
          Comprar por WhatsApp
        </Button>
      </div>
    </SheetContent>
  </Sheet>
</template>
