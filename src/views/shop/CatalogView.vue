<script setup>
import { ref, computed, onMounted } from 'vue'
import { Search } from '@lucide/vue'
import { Skeleton } from '@/components/ui/skeleton'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import ProductGrid from '@/components/shop/ProductGrid.vue'
import ProductSearch from '@/components/shop/ProductSearch.vue'

const loading = ref(true)
const products = ref([])
const stores = ref([])
const search = ref('')
const sortBy = ref('name')
const storeFilter = ref('all')

onMounted(async () => {
  const [productsRes, storesRes] = await Promise.all([
    supabase.from('products').select('*, stores(name, slug, phone)').eq('is_active', true),
    supabase.from('stores').select('id, name').order('name'),
  ])
  if (productsRes.error) {
    toast.error('Error al cargar productos')
  } else {
    products.value = (productsRes.data ?? []).map((p) => ({ ...p, store: p.stores }))
  }
  if (!storesRes.error) stores.value = storesRes.data ?? []
  loading.value = false
})

const filteredProducts = computed(() => {
  let result = [...products.value]
  if (storeFilter.value !== 'all') {
    result = result.filter((p) => p.store_id === storeFilter.value)
  }
  const q = search.value.trim().toLowerCase()
  if (q) {
    result = result.filter(
      (p) => p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q)
    )
  }
  if (sortBy.value === 'price-asc') {
    result.sort((a, b) => a.price - b.price)
  } else if (sortBy.value === 'price-desc') {
    result.sort((a, b) => b.price - a.price)
  } else {
    result.sort((a, b) => a.name.localeCompare(b.name))
  }
  return result
})
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <ProductSearch
      v-model:search="search"
      v-model:sort-by="sortBy"
      :result-count="loading ? 0 : filteredProducts.length"
    />

    <div v-if="stores.length > 0" class="mt-6 flex flex-wrap gap-2">
      <button
        class="rounded-full border px-3 py-1 text-xs font-medium transition-colors"
        :class="
          storeFilter === 'all'
            ? 'border-ucla-600 bg-ucla-50 text-ucla-600'
            : 'border-neutral-200 text-neutral-500 hover:border-neutral-300'
        "
        @click="storeFilter = 'all'"
      >
        Todas las tiendas
      </button>
      <button
        v-for="store in stores"
        :key="store.id"
        class="rounded-full border px-3 py-1 text-xs font-medium transition-colors"
        :class="
          storeFilter === store.id
            ? 'border-ucla-600 bg-ucla-50 text-ucla-600'
            : 'border-neutral-200 text-neutral-500 hover:border-neutral-300'
        "
        @click="storeFilter = store.id"
      >
        {{ store.name }}
      </button>
    </div>

    <div v-if="loading" class="mt-8">
      <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <Skeleton v-for="i in 6" :key="i" class="aspect-[4/5] rounded-xl" />
      </div>
    </div>

    <div v-else-if="filteredProducts.length === 0" class="mt-16 text-center">
      <Search class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">
        No encontramos productos para
        <span class="font-medium text-ucla-900/60">"{{ search }}"</span>
      </p>
      <button
        class="mt-2 text-sm text-ucla-600 underline underline-offset-2 hover:text-ucla-700"
        @click="search = ''"
      >
        Limpiar búsqueda
      </button>
    </div>

    <div v-else class="mt-8">
      <ProductGrid :products="filteredProducts" :columns="3" />
    </div>
  </div>
</template>