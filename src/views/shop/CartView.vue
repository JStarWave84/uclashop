<script setup>
import { onMounted, computed } from 'vue'
import { Button } from '@/components/ui/button'
import { useCartStore } from '@/stores/cart'
import { ShoppingCart, MessageCircle, ArrowRight, Store } from '@lucide/vue'
import { useRouter } from 'vue-router'
import CartItemRow from '@/components/shop/CartItemRow.vue'
import OrderSummary from '@/components/shop/OrderSummary.vue'
import { groupCartByStore, buildCartMessage, buildWhatsAppUrl } from '@/lib/whatsapp'

const cart = useCartStore()
const router = useRouter()

onMounted(() => {
  cart.loadJornadaProducts()
})

function goTo(path) {
  router.push(path)
}

const storeGroups = computed(() => groupCartByStore(cart.items))

function buyOnWhatsApp(phone, items, total) {
  const message = buildCartMessage(items, total)
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
          <p
            v-if="!cart.isJornadaCart && cart.cartStore"
            class="mb-2 flex items-center gap-1.5 text-xs font-medium text-ucla-900/50"
          >
            <Store class="size-3.5 shrink-0 text-ucla-600" />
            Productos de {{ cart.cartStore.name }}
          </p>
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

          <template v-else>
            <div
              v-for="group in storeGroups"
              :key="group.storeId"
              class="mt-4 rounded-xl border border-ucla-100 bg-ucla-50/50 p-4"
            >
              <div class="flex items-center justify-between gap-2">
                <p class="inline-flex min-w-0 items-center gap-1.5 text-sm font-semibold text-ucla-900">
                  <Store class="size-4 shrink-0 text-ucla-600" />
                  <span class="truncate">{{ group.store.name }}</span>
                </p>
                <router-link
                  v-if="group.store.slug"
                  :to="`/tiendas/${group.store.slug}`"
                  class="shrink-0 text-xs text-ucla-600 underline underline-offset-2 hover:text-ucla-700"
                >
                  Ver tienda
                </router-link>
              </div>
              <p class="mt-1 text-xs text-ucla-900/50">
                {{ group.items.length }}
                {{ group.items.length === 1 ? 'producto' : 'productos' }} de esta tienda
              </p>
              <Button
                class="mt-3 w-full"
                size="lg"
                @click="buyOnWhatsApp(group.phone, group.items, group.total)"
              >
                <MessageCircle class="size-4" />
                Enviar pedido a {{ group.store.name }}
              </Button>
            </div>
          </template>
        </aside>
      </div>
    </template>
  </div>
</template>