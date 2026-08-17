<script setup>
import { onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { useCartStore } from '@/stores/cart'
import { ShoppingCart, MessageCircle, ArrowRight } from '@lucide/vue'
import { useRouter } from 'vue-router'
import CartItemRow from '@/components/shop/CartItemRow.vue'
import OrderSummary from '@/components/shop/OrderSummary.vue'
import { resolveContactPhone, buildCartMessage, buildWhatsAppUrl } from '@/lib/whatsapp'

const cart = useCartStore()
const router = useRouter()

onMounted(() => {
  cart.loadJornadaProducts()
})

function goTo(path) {
  router.push(path)
}

async function buyOnWhatsApp() {
  const phone = resolveContactPhone(cart.items)
  const message = buildCartMessage(cart.items, cart.totalPrice)
  window.open(buildWhatsAppUrl(phone, message), '_blank', 'noopener,noreferrer')
}
</script>

<template>
  <div class="mx-auto max-w-3xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <h1
      class="text-3xl font-semibold tracking-tight text-ucla-900 sm:text-4xl"
      style="font-family: var(--font-display)"
    >
      Carrito de compras
    </h1>

    <div v-if="cart.items.length === 0" class="mt-16 text-center">
      <ShoppingCart class="mx-auto size-12 text-ucla-900/20" />
      <p class="mt-4 text-base text-ucla-900/40">Tu carrito está vacío</p>
      <Button variant="outline" class="mt-4" @click="goTo('/productos')">
        Explorar productos
      </Button>
    </div>

    <template v-else>
      <div class="mt-8 grid gap-8 lg:grid-cols-5">
        <div class="lg:col-span-3">
          <div class="divide-y divide-ucla-100">
            <CartItemRow v-for="item in cart.items" :key="item.id" :item="item" />
          </div>
        </div>

        <aside class="lg:col-span-2">
          <OrderSummary :items="cart.items" :total="cart.totalPrice" />
          <Button
            v-if="cart.isJornadaCart"
            @click="goTo('/checkout')"
            class="mt-4 w-full"
            size="lg"
          >
            Proceder al pago
            <ArrowRight class="size-4" />
          </Button>
          <Button v-else @click="buyOnWhatsApp" class="mt-4 w-full" size="lg">
            <MessageCircle class="size-4" />
            Comprar por WhatsApp
          </Button>
        </aside>
      </div>
    </template>
  </div>
</template>
