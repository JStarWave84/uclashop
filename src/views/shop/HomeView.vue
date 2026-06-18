<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { ArrowRight } from '@lucide/vue'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import ProductGrid from '@/components/shop/ProductGrid.vue'
import SessionBanner from '@/components/shop/SessionBanner.vue'

const loading = ref(true)
const products = ref([])
const currentSession = ref(null)

const featuredProducts = computed(() => products.value.slice(0, 4))

onMounted(async () => {
  const [sessionRes, productsRes] = await Promise.all([
    supabase.from('sales_sessions').select('*').eq('is_open', true).limit(1),
    supabase.from('products').select('*').eq('is_active', true).limit(6),
  ])

  if (sessionRes.data?.length) {
    currentSession.value = sessionRes.data[0]
  }

  if (productsRes.error) {
    toast.error('Error al cargar productos')
  } else {
    products.value = productsRes.data ?? []
  }

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
        :product-count="products.length"
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
          <p class="mt-1 text-sm text-ucla-900/50">Lo más popular de la jornada</p>
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
