<script setup>
import { ref, computed, onMounted } from 'vue'
import { Store, MessageCircle, Package, Search } from '@lucide/vue'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { storeLogoUrl } from '@/lib/storage'
import { normalizeWhatsAppPhone } from '@/lib/whatsapp'

const loading = ref(true)
const stores = ref([])
const search = ref('')

onMounted(async () => {
  const [storesRes, productsRes] = await Promise.all([
    supabase.from('stores').select('*').order('name'),
    supabase.from('products').select('store_id').eq('is_active', true),
  ])
  if (storesRes.error) {
    console.error('fetchStores', storesRes.error)
    toast.error('No se pudieron cargar las tiendas')
  }
  const countMap = {}
  for (const p of productsRes.data || []) {
    countMap[p.store_id] = (countMap[p.store_id] || 0) + 1
  }
  stores.value = (storesRes.data || []).map((s) => ({ ...s, product_count: countMap[s.id] || 0 }))
  loading.value = false
})

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return stores.value
  return stores.value.filter((s) => `${s.name} ${s.description || ''}`.toLowerCase().includes(q))
})

function waUrl(store) {
  const phone = normalizeWhatsAppPhone(store.phone)
  if (!phone) return null
  const msg = encodeURIComponent(`¡Hola! 😊 Quería consultar sobre tu tienda ${store.name}`)
  return `https://wa.me/${phone}?text=${msg}`
}
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1
          class="text-3xl font-semibold tracking-tight text-ucla-900 sm:text-4xl"
          style="font-family: var(--font-display)"
        >
          Tiendas
        </h1>
        <p class="mt-2 text-sm text-ucla-900/50">
          Explorá los distintos negocios del marketplace de la comunidad universitaria.
        </p>
      </div>

      <div class="relative">
        <Search class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
        <input
          v-model="search"
          type="search"
          placeholder="Buscar tiendas..."
          class="h-10 w-full rounded-lg border border-ucla-100 bg-white pl-9 pr-3 text-sm text-ucla-900 outline-none transition-colors focus:border-ucla-400 sm:w-64"
        />
      </div>
    </div>

    <div v-if="loading" class="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <Skeleton v-for="i in 6" :key="i" class="h-44 rounded-2xl" />
    </div>

    <div v-else-if="filtered.length === 0" class="mt-16 text-center">
      <Store class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">
        No encontramos tiendas para
        <span class="font-medium text-ucla-900/60">"{{ search }}"</span>
      </p>
      <button
        class="mt-2 text-sm text-ucla-600 underline underline-offset-2 hover:text-ucla-700"
        @click="search = ''"
      >
        Limpiar búsqueda
      </button>
    </div>

    <div v-else class="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <div
        v-for="store in filtered"
        :key="store.id"
        class="group relative flex flex-col rounded-2xl border border-ucla-100 bg-white p-6 transition-all hover:shadow-md"
      >
        <div class="flex items-center gap-4">
          <div
            class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br from-ucla-50 to-ucla-100"
          >
            <img
              v-if="store.logo_path"
              :src="storeLogoUrl(store.logo_path)"
              :alt="store.name"
              class="size-full object-cover"
            />
            <Store v-else class="size-7 text-ucla-300" />
          </div>
          <div class="min-w-0">
            <h2 class="truncate text-lg font-semibold text-ucla-900">{{ store.name }}</h2>
            <p class="text-xs text-ucla-900/40">/tiendas/{{ store.slug }}</p>
          </div>
        </div>

        <p class="mt-4 line-clamp-2 flex-1 text-sm leading-relaxed text-ucla-900/60">
          {{ store.description || 'Tienda del marketplace universitario.' }}
        </p>

        <div class="mt-5 flex items-center justify-between">
          <span class="inline-flex items-center gap-1.5 text-xs font-medium text-ucla-900/50">
            <Package class="size-3.5" />
            {{ store.product_count }}
            {{ store.product_count === 1 ? 'producto' : 'productos' }}
          </span>
          <a
            v-if="waUrl(store)"
            :href="waUrl(store)"
            target="_blank"
            rel="noopener noreferrer"
            class="relative z-10 inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-600 transition-colors hover:bg-emerald-100"
          >
            <MessageCircle class="size-3.5" />
            WhatsApp
          </a>
        </div>

        <router-link
          :to="`/tiendas/${store.slug}`"
          class="absolute inset-0 rounded-2xl focus:outline-none focus-visible:ring-2 focus-visible:ring-ucla-500 focus-visible:ring-offset-2"
          :aria-label="'Ver tienda ' + store.name"
        >
          <span class="sr-only">Ver tienda {{ store.name }}</span>
        </router-link>
      </div>
    </div>
  </div>
</template>