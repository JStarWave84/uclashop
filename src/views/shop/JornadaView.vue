<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { ShoppingCart, ArrowRight, Calendar, Package, AlertCircle } from '@lucide/vue'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { useCartStore } from '@/stores/cart'
import ProductGrid from '@/components/shop/ProductGrid.vue'
import OrderSummary from '@/components/shop/OrderSummary.vue'

const router = useRouter()
const cart = useCartStore()

const loading = ref(true)
const session = ref(null)
const sessionProducts = ref([])

onMounted(async () => {
  const { data: sessionsData, error } = await supabase
    .from('sales_sessions')
    .select('*')
    .eq('is_open', true)
    .limit(1)
  if (error) {
    console.error('fetchSession', error)
    toast.error('No se pudo cargar la jornada')
    loading.value = false
    return
  }
  if (!sessionsData || sessionsData.length === 0) {
    loading.value = false
    return
  }
  session.value = sessionsData[0]

  // get product ids from product_sessions
  const { data: ps, error: psErr } = await supabase
    .from('product_sessions')
    .select('product_id')
    .eq('session_id', session.value.id)
  if (psErr) {
    console.error('fetchProductSessions', psErr)
    loading.value = false
    return
  }
  const pids = (ps || []).map((x) => x.product_id)
  if (pids.length === 0) {
    loading.value = false
    return
  }

  const { data: prods, error: pErr } = await supabase.from('products').select('*').in('id', pids)
  if (pErr) {
    console.error('fetchProducts', pErr)
    loading.value = false
    return
  }
  sessionProducts.value = prods || []
  loading.value = false
})

function formatDateRange(start, end) {
  const opts = { day: 'numeric', month: 'long', year: 'numeric' }
  return `${new Date(start).toLocaleDateString('es-ES', opts)} al ${new Date(end).toLocaleDateString('es-ES', opts)}`
}

function goTo(path) {
  router.push(path)
}
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <section
      class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-ucla-50 via-white to-ucla-50"
    >
      <div v-if="loading" class="space-y-4 px-6 py-10 sm:px-10 sm:py-14 lg:px-14 lg:py-16">
        <div class="flex gap-3">
          <Skeleton class="h-6 w-20 rounded-full" />
          <Skeleton class="h-6 w-28 rounded-full" />
        </div>
        <Skeleton class="h-12 w-3/4 sm:h-14" />
        <Skeleton class="h-4 w-64" />
        <Skeleton class="h-4 w-80" />
      </div>

      <div v-else class="relative z-10 px-6 py-10 sm:px-10 sm:py-14 lg:px-14 lg:py-16">
        <div class="flex items-center gap-3">
          <span
            class="inline-block rounded-full border px-3 py-1 text-[11px] font-medium uppercase tracking-widest"
            :class="
              session?.is_open
                ? 'border-emerald-200 bg-emerald-50 text-emerald-600'
                : 'border-neutral-200 bg-neutral-50 text-neutral-500'
            "
          >
            {{ session?.is_open ? 'Abierta' : 'Cerrada' }}
          </span>
          <span
            v-if="session"
            class="inline-flex items-center gap-1.5 rounded-full border border-ucla-200 bg-ucla-50 px-3 py-1 text-[11px] font-medium uppercase tracking-widest text-ucla-600"
          >
            <Package class="size-3" />
            {{ sessionProducts.length }}
            {{ sessionProducts.length === 1 ? 'producto' : 'productos' }}
          </span>
        </div>

        <h1
          class="mt-4 max-w-2xl text-3xl font-semibold leading-tight tracking-tight text-ucla-900 sm:text-4xl lg:text-5xl"
          style="font-family: var(--font-display)"
        >
          {{ session?.name }}
        </h1>

        <p class="mt-2 inline-flex items-center gap-1.5 text-sm text-ucla-900/60">
          <Calendar class="size-4" />
          {{ formatDateRange(session?.start_date, session?.end_date) }}
        </p>

        <p class="mt-1 text-sm text-ucla-900/50">
          Comprá los productos disponibles en esta jornada. Agregalos al carrito y procedé al pago.
        </p>
      </div>

      <div
        class="pointer-events-none absolute -bottom-8 -right-8 select-none text-[200px] font-display font-bold leading-none text-ucla-100/40 sm:text-[280px]"
        aria-hidden="true"
      >
        UCLA
      </div>
    </section>

    <div v-if="loading" class="mt-8 grid gap-8 lg:grid-cols-5">
      <div class="grid gap-5 sm:grid-cols-2 lg:col-span-3">
        <Skeleton v-for="i in 4" :key="i" class="aspect-[4/5] rounded-xl" />
      </div>
      <Skeleton class="h-48 rounded-xl lg:col-span-2" />
    </div>

    <div v-else-if="!session" class="mt-10 text-center">
      <AlertCircle class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">No hay ninguna jornada activa en este momento.</p>
      <Button variant="outline" class="mt-4" @click="goTo('/')"> Volver al inicio </Button>
    </div>

    <div v-else-if="!session.is_open" class="mt-10 text-center">
      <AlertCircle class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">
        Esta jornada se encuentra cerrada. No se pueden realizar pedidos.
      </p>
      <Button variant="outline" class="mt-4" @click="goTo('/')"> Volver al inicio </Button>
    </div>

    <div v-else-if="sessionProducts.length === 0" class="mt-10 text-center">
      <Package class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">No hay productos disponibles en esta jornada.</p>
    </div>

    <div v-else class="mt-8 grid gap-8 lg:grid-cols-5">
      <div class="lg:col-span-3">
        <ProductGrid :products="sessionProducts" :columns="2" />
      </div>

      <aside class="lg:col-span-2">
        <div class="lg:sticky lg:top-24">
          <OrderSummary v-if="cart.items.length > 0" :items="cart.items" :total="cart.totalPrice" />

          <div
            v-else
            class="flex flex-col items-center gap-3 rounded-xl border border-ucla-100 bg-ucla-50/50 p-8 text-center"
          >
            <ShoppingCart class="size-8 text-ucla-900/20" />
            <p class="text-sm text-ucla-900/40">Tu carrito está vacío</p>
            <p class="text-xs text-ucla-900/30">
              Agregá productos de la jornada para ver el resumen.
            </p>
          </div>

          <Button
            v-if="cart.items.length > 0"
            @click="goTo('/checkout')"
            class="mt-4 w-full"
            size="lg"
          >
            Proceder al pago
            <ArrowRight class="size-4" />
          </Button>

          <router-link
            to="/productos"
            class="mt-3 block text-center text-xs text-ucla-600 underline underline-offset-2 hover:text-ucla-700"
          >
            Ver catálogo completo
          </router-link>
        </div>
      </aside>
    </div>
  </div>
</template>
