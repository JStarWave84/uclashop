<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { ArrowRight, Store } from '@lucide/vue'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import ProductGrid from '@/components/shop/ProductGrid.vue'
import SessionBanner from '@/components/shop/SessionBanner.vue'
import { storeLogoUrl } from '@/lib/storage'

const loading = ref(true)
const products = ref([])
const stores = ref([])
const currentSession = ref(null)
const sessionProductCount = ref(0)

const featuredProducts = computed(() => products.value.slice(0, 4))

onMounted(async () => {
  const [sessionRes, productsRes, storesRes] = await Promise.all([
    supabase.from('sales_sessions').select('*').eq('is_open', true).limit(1),
    supabase.from('products').select('*, stores(name, slug, phone)').eq('is_active', true).limit(6),
    supabase.from('stores').select('*').order('name').limit(4),
  ])

  if (sessionRes.data?.length) {
    currentSession.value = sessionRes.data[0]
    const { count } = await supabase
      .from('product_sessions')
      .select('product_id', { count: 'exact', head: true })
      .eq('session_id', currentSession.value.id)
    sessionProductCount.value = count || 0
  }

  if (productsRes.error) {
    toast.error('Error al cargar productos')
  } else {
    products.value = (productsRes.data ?? []).map((p) => ({ ...p, store: p.stores }))
  }

  if (!storesRes.error) stores.value = storesRes.data ?? []

  loading.value = false
})
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
    <div class="mt-6 sm:mt-8">
      <Skeleton v-if="loading" class="h-56 rounded-2xl sm:h-64" />

      <SessionBanner
        v-else-if="currentSession"
        :session="currentSession"
        :product-count="sessionProductCount"
      />
    </div>

    <section class="py-12 sm:py-16">
      <div v-if="loading" class="flex items-end justify-between">
        <div class="space-y-2">
          <Skeleton class="h-8 w-64" />
          <Skeleton class="h-4 w-44" />
        </div>
      </div>

      <div v-else class="flex items-end justify-between">
        <div>
          <h2
            class="text-2xl font-semibold leading-tight tracking-tight text-ucla-900"
            style="font-family: var(--font-display)"
          >
            Productos destacados
          </h2>
          <p class="mt-1 text-sm text-ucla-900/50">Lo más popular del marketplace</p>
        </div>
      </div>

      <div v-if="loading" class="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <Skeleton v-for="i in 4" :key="i" class="aspect-[4/5] rounded-xl" />
      </div>

      <div v-else class="mt-8">
        <ProductGrid :products="featuredProducts" :columns="4" />
      </div>

      <div class="mt-10 text-center">
        <router-link to="/productos">
          <Button variant="outline" size="lg">
            Explorar catálogo completo
            <ArrowRight class="size-4" />
          </Button>
        </router-link>
      </div>
    </section>

    <section v-if="stores.length > 0" class="pb-12 sm:pb-16">
      <div class="flex items-end justify-between">
        <div>
          <h2
            class="text-2xl font-semibold leading-tight tracking-tight text-ucla-900"
            style="font-family: var(--font-display)"
          >
            Tiendas del marketplace
          </h2>
          <p class="mt-1 text-sm text-ucla-900/50">Distintos negocios de la comunidad</p>
        </div>
        <router-link
          to="/tiendas"
          class="text-sm font-medium text-ucla-600 underline underline-offset-2 hover:text-ucla-700"
        >
          Ver todas
        </router-link>
      </div>

      <div class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <router-link
          v-for="store in stores"
          :key="store.id"
          :to="`/tiendas/${store.slug}`"
          class="group flex items-center gap-3 rounded-xl border border-ucla-100 bg-white p-4 transition-all hover:shadow-md"
        >
          <div class="flex size-12 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-gradient-to-br from-ucla-50 to-ucla-100">
            <img
              v-if="store.logo_path"
              :src="storeLogoUrl(store.logo_path)"
              :alt="store.name"
              class="size-full object-cover"
            />
            <Store v-else class="size-5 text-ucla-300" />
          </div>
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold text-ucla-900 group-hover:text-ucla-600">
              {{ store.name }}
            </p>
            <p class="truncate text-xs text-ucla-900/40">/tiendas/{{ store.slug }}</p>
          </div>
        </router-link>
      </div>
    </section>

    <section
      class="mb-12 overflow-hidden rounded-2xl bg-ucla-900 px-6 py-10 sm:mb-16 sm:px-10 sm:py-14"
    >
      <div class="mx-auto max-w-2xl text-center">
        <span class="text-sm font-medium uppercase tracking-widest text-ucla-gold-light">
          Pago
        </span>
        <h2
          class="mt-2 text-2xl font-semibold leading-tight text-white sm:text-3xl"
          style="font-family: var(--font-display)"
        >
          Paga con pago móvil o transferencia
        </h2>
        <p class="mt-3 text-sm leading-relaxed text-ucla-200/70">
          Seleccioná tus productos, creá tu pedido y te asignamos una cuenta para pagar. Una vez
          realizado el pago, envianos el comprobante para confirmar tu orden.
        </p>
        <div class="mt-6 flex justify-center gap-8 text-sm text-ucla-200/60">
          <span class="flex items-center gap-2">
            <span class="inline-block size-1.5 rounded-full bg-ucla-gold" />
            Pago móvil
          </span>
          <span class="flex items-center gap-2">
            <span class="inline-block size-1.5 rounded-full bg-ucla-gold" />
            Transferencia
          </span>
        </div>
      </div>
    </section>
  </div>
</template>