<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useHead } from '@unhead/vue'
import { ArrowLeft, Store, MessageCircle, Package, AlertCircle } from '@lucide/vue'
import { Skeleton } from '@/components/ui/skeleton'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { storeLogoUrl } from '@/lib/storage'
import { normalizeWhatsAppPhone } from '@/lib/whatsapp'
import ProductGrid from '@/components/shop/ProductGrid.vue'

const route = useRoute()
const loading = ref(true)
const store = ref(null)
const products = ref([])

const defaultDescription =
  'Marketplace universitario de la UCLA: explorá las tiendas de la comunidad y descubrí sus productos.'

useHead(
  computed(() => ({
    title: store.value?.name,
    meta: [
      {
        key: 'description',
        name: 'description',
        content: store.value?.description || defaultDescription,
      },
      {
        key: 'og:title',
        property: 'og:title',
        content: store.value?.name,
      },
      {
        key: 'og:description',
        property: 'og:description',
        content: store.value?.description || defaultDescription,
      },
      {
        key: 'og:image',
        property: 'og:image',
        content: store.value?.logo_path ? storeLogoUrl(store.value.logo_path) : '/og-default.png',
      },
      {
        key: 'og:url',
        property: 'og:url',
        content: store.value ? `${window.location.origin}${route.path}` : undefined,
      },
      {
        key: 'twitter:title',
        name: 'twitter:title',
        content: store.value?.name,
      },
      {
        key: 'twitter:description',
        name: 'twitter:description',
        content: store.value?.description || defaultDescription,
      },
      {
        key: 'twitter:image',
        name: 'twitter:image',
        content: store.value?.logo_path ? storeLogoUrl(store.value.logo_path) : '/og-default.png',
      },
    ],
  })),
)

onMounted(async () => {
  const { data: storeData, error } = await supabase
    .from('stores')
    .select('*')
    .eq('slug', route.params.slug)
    .maybeSingle()
  if (error || !storeData) {
    if (error) console.error('fetchStore', error)
    loading.value = false
    return
  }
  store.value = storeData

  const { data: prods, error: pErr } = await supabase
    .from('products')
    .select('*')
    .eq('store_id', storeData.id)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
  if (pErr) {
    console.error('fetchProducts', pErr)
    toast.error('No se pudieron cargar los productos')
  } else {
    products.value = (prods || []).map((p) => ({ ...p, store }))
  }
  loading.value = false
})

const waUrl = computed(() => {
  const phone = normalizeWhatsAppPhone(store.value?.phone)
  if (!phone) return null
  const msg = encodeURIComponent(`¡Hola! 😊 Quería consultar sobre un producto de ${store.value.name}`)
  return `https://wa.me/${phone}?text=${msg}`
})
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <router-link
      to="/tiendas"
      class="inline-flex items-center gap-1.5 text-sm text-ucla-900/50 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver a tiendas
    </router-link>

    <div v-if="loading" class="mt-6">
      <Skeleton class="h-40 rounded-2xl" />
      <div class="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <Skeleton v-for="i in 6" :key="i" class="aspect-[4/5] rounded-xl" />
      </div>
    </div>

    <div v-else-if="!store" class="mt-16 text-center">
      <AlertCircle class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">Tienda no encontrada</p>
      <Button variant="outline" class="mt-4" as="router-link" to="/tiendas">
        Ver tiendas
      </Button>
    </div>

    <template v-else>
      <section
        class="mt-6 overflow-hidden rounded-2xl border border-ucla-100 bg-gradient-to-br from-ucla-50 via-white to-ucla-50 p-6 sm:p-10"
      >
        <div class="flex flex-col gap-6 sm:flex-row sm:items-center">
          <div
            class="flex size-24 shrink-0 items-center justify-center overflow-hidden rounded-3xl bg-white shadow-sm sm:size-28"
          >
            <img
              v-if="store.logo_path"
              :src="storeLogoUrl(store.logo_path)"
              :alt="store.name"
              class="size-full object-cover"
            />
            <Store v-else class="size-10 text-ucla-300" />
          </div>

          <div class="min-w-0 flex-1">
            <h1
              class="text-3xl font-semibold leading-tight tracking-tight text-ucla-900 sm:text-4xl"
              style="font-family: var(--font-display)"
            >
              {{ store.name }}
            </h1>
            <p class="mt-2 text-sm leading-relaxed text-ucla-900/60">
              {{ store.description || 'Tienda del marketplace universitario.' }}
            </p>
            <div class="mt-4 flex flex-wrap items-center gap-3 text-xs text-ucla-900/50">
              <span class="inline-flex items-center gap-1.5">
                <Package class="size-3.5" />
                {{ products.length }}
                {{ products.length === 1 ? 'producto' : 'productos' }}
              </span>
            </div>
          </div>

          <a v-if="waUrl" :href="waUrl" target="_blank" rel="noopener noreferrer" class="shrink-0">
            <Button size="lg">
              <MessageCircle class="size-4" />
              Escribir por WhatsApp
            </Button>
          </a>
        </div>
      </section>

      <section class="mt-10">
        <h2 class="text-xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Productos de {{ store.name }}
        </h2>

        <div v-if="products.length === 0" class="mt-6 rounded-xl border border-ucla-100 bg-white py-16 text-center">
          <Package class="mx-auto size-8 text-ucla-900/20" />
          <p class="mt-3 text-sm text-ucla-900/40">Esta tienda todavía no tiene productos publicados.</p>
        </div>

        <div v-else class="mt-6">
          <ProductGrid :products="products" :columns="3" />
        </div>
      </section>
    </template>
  </div>
</template>