<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useHead } from '@unhead/vue'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { useCartStore } from '@/stores/cart'
import { ShoppingCart, Minus, Plus, ArrowLeft, Package, Store } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { formatPrice } from '@/lib/utils'

const route = useRoute()
const cart = useCartStore()

const loading = ref(true)
const product = ref(null)
const quantity = ref(1)
const variants = ref([])
const selectedAttrs = ref({})

function productImageUrl(path) {
  if (!path) return null
  const {
    data: { publicUrl },
  } = supabase.storage.from('product-images').getPublicUrl(path)
  return publicUrl
}

useHead(
  computed(() => {
    const description = product.value?.store
      ? `${product.value.description || `Producto de ${product.value.store.name}`} · ${formatPrice(product.value.price)}`
      : product.value?.description || 'Producto del marketplace universitario UCLA Shop.'
    const image = product.value?.product_image_path
      ? productImageUrl(product.value.product_image_path)
      : '/og-default.png'
    return {
      title: product.value?.name,
      meta: [
        { key: 'description', name: 'description', content: description },
        { key: 'og:title', property: 'og:title', content: product.value?.name },
        { key: 'og:description', property: 'og:description', content: description },
        { key: 'og:image', property: 'og:image', content: image },
        {
          key: 'og:url',
          property: 'og:url',
          content: product.value ? `${window.location.origin}${route.path}` : undefined,
        },
        { key: 'twitter:title', name: 'twitter:title', content: product.value?.name },
        { key: 'twitter:description', name: 'twitter:description', content: description },
        { key: 'twitter:image', name: 'twitter:image', content: image },
      ],
    }
  }),
)

onMounted(async () => {
  const { data, error } = await supabase
    .from('products')
    .select('*, stores(name, slug, phone)')
    .eq('id', route.params.id)
    .single()

  if (error) {
    toast.error('Error al cargar el producto')
  } else {
    product.value = { ...data, store: data.stores }

    if (data.has_variants) {
      const { data: vs } = await supabase
        .from('product_variants')
        .select('*')
        .eq('product_id', route.params.id)
        .eq('is_active', true)
        .order('created_at')
      variants.value = vs || []
      initSelection()
    }
  }

  loading.value = false
})

// --- Variant selection ---

const hasVariants = computed(
  () => !!product.value?.has_variants && variants.value.length > 0
)

const attrGroups = computed(() => {
  const names = []
  for (const v of variants.value) {
    for (const name of Object.keys(v.attributes || {})) {
      if (!names.includes(name)) names.push(name)
    }
  }
  return names.map((name) => {
    const seen = new Set()
    const options = []
    for (const v of variants.value) {
      const value = (v.attributes || {})[name]
      if (value == null || seen.has(value)) continue
      seen.add(value)
      options.push({
        value,
        hasStock: variants.value.some(
          (x) => (x.attributes || {})[name] === value && x.stock > 0
        ),
      })
    }
    return { name, options }
  })
})

function combosMatching(partial) {
  return variants.value.filter((v) =>
    Object.entries(partial).every(
      ([k, val]) => val == null || (v.attributes || {})[k] === val
    )
  )
}

function initSelection() {
  const initial = {}
  for (const group of attrGroups.value) {
    const candidates = combosMatching(initial).filter(
      (v) => (v.attributes || {})[group.name] != null
    )
    const preferred = candidates.find((v) => v.stock > 0) || candidates[0]
    initial[group.name] = preferred ? preferred.attributes[group.name] : null
  }
  selectedAttrs.value = initial
}

function selectAttr(name, value) {
  const next = { ...selectedAttrs.value, [name]: value }
  for (const group of attrGroups.value) {
    if (group.name === name) continue
    const current = next[group.name]
    const candidates = combosMatching({ ...next, [group.name]: null })
    const stillValid =
      current != null &&
      candidates.some((v) => (v.attributes || {})[group.name] === current)
    if (!stillValid) {
      const preferred =
        candidates.find(
          (v) => (v.attributes || {})[group.name] != null && v.stock > 0
        ) || candidates[0]
      next[group.name] = preferred
        ? (preferred.attributes || {})[group.name] ?? null
        : null
    }
  }
  selectedAttrs.value = next
}

const selectedVariant = computed(() => {
  if (!hasVariants.value) return null
  return (
    variants.value.find((v) =>
      attrGroups.value.every(
        (g) => (v.attributes || {})[g.name] === selectedAttrs.value[g.name]
      )
    ) || null
  )
})

function addToCart() {
  if (!product.value) return
  cart.addItem(product.value, quantity.value, selectedVariant.value)
  quantity.value = 1
}

const LOW_STOCK_THRESHOLD = 5

const availableStock = computed(() =>
  hasVariants.value ? (selectedVariant.value?.stock ?? 0) : (product.value?.stock ?? 0)
)

const effectivePrice = computed(() => {
  if (!product.value) return 0
  if (selectedVariant.value?.price != null) return selectedVariant.value.price
  return product.value.price
})

const stockLabel = computed(() => {
  const p = product.value
  if (!p) return ''
  if (hasVariants.value && !selectedVariant.value) return 'Elige una opción'
  if (availableStock.value > LOW_STOCK_THRESHOLD) return `Disponible: ${availableStock.value}`
  if (availableStock.value > 0) return `Por agotarse: ${availableStock.value}`
  if (p.allow_backorder) return 'Acepta backorder'
  return 'Agotado'
})

const stockVariant = computed(() => {
  const p = product.value
  if (!p) return ''
  if (hasVariants.value && !selectedVariant.value) return 'text-ucla-600 bg-ucla-50'
  if (availableStock.value > LOW_STOCK_THRESHOLD) return 'text-emerald-600 bg-emerald-50'
  if (availableStock.value > 0) return 'text-amber-600 bg-amber-50'
  if (p.allow_backorder) return 'text-ucla-gold bg-ucla-gold/10'
  return 'text-red-500 bg-red-50'
})

const canAddToCart = computed(() => {
  const p = product.value
  if (!p) return false
  if (hasVariants.value) return !!selectedVariant.value && (selectedVariant.value.stock > 0 || p.allow_backorder)
  return p.stock > 0 || p.allow_backorder
})
</script>

<template>
  <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <router-link
      to="/productos"
      class="inline-flex items-center gap-1.5 text-sm text-ucla-900/50 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver al catálogo
    </router-link>

    <div v-if="loading" class="mt-6 grid gap-8 lg:grid-cols-2 lg:gap-14">
      <Skeleton class="aspect-[4/3] rounded-2xl" />

      <div class="flex flex-col gap-5">
        <Skeleton class="h-10 w-3/4" />
        <Skeleton class="h-5 w-24 rounded-full" />
        <Skeleton class="h-20 w-full" />
        <Skeleton class="h-9 w-1/3" />
        <Skeleton class="h-11 w-40 rounded-xl" />
        <Skeleton class="h-12 w-full sm:w-48" />
        <Skeleton class="h-24 w-full" />
      </div>
    </div>

    <div v-else-if="product" class="mt-6 grid gap-8 lg:grid-cols-2 lg:gap-14">
      <div
        class="flex aspect-[4/3] items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br from-ucla-50 to-ucla-100"
      >
        <img
          v-if="product.product_image_path"
          :src="productImageUrl(product.product_image_path)"
          :alt="product.name"
          class="size-full object-cover"
        />
        <span
          v-else
          class="text-7xl font-display font-bold tracking-tight text-ucla-200/60 sm:text-8xl"
        >
          UCLA
        </span>
      </div>

      <div class="flex flex-col gap-5">
        <div>
          <h1
            class="text-3xl font-semibold leading-tight tracking-tight text-ucla-900 sm:text-4xl"
            style="font-family: var(--font-display)"
          >
            {{ product.name }}
          </h1>

          <router-link
            v-if="product.store"
            :to="`/tiendas/${product.store.slug}`"
            class="mt-2 inline-flex items-center gap-1.5 text-sm font-medium text-ucla-600 transition-colors hover:text-ucla-700"
          >
            <Store class="size-4" />
            {{ product.store.name }}
          </router-link>

          <span
            class="mt-3 inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium capitalize"
            :class="stockVariant"
          >
            <Package class="size-3.5" />
            {{ stockLabel }}
          </span>
        </div>

        <p class="text-sm leading-relaxed text-ucla-900/60">
          {{ product.description }}
        </p>

        <span class="text-3xl font-semibold tracking-tight text-ucla-700">
          {{ formatPrice(effectivePrice) }}
        </span>

        <div v-for="group in attrGroups" :key="group.name" class="flex flex-col gap-2">
          <span class="text-xs font-medium uppercase tracking-wide text-ucla-900/50">
            {{ group.name }}
          </span>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="opt in group.options"
              :key="opt.value"
              type="button"
              :disabled="!opt.hasStock && !product.allow_backorder"
              class="rounded-lg border px-4 py-2 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-40"
              :class="
                selectedAttrs[group.name] === opt.value
                  ? 'border-ucla-700 bg-ucla-700 text-white'
                  : 'border-ucla-200 bg-white text-ucla-900 hover:border-ucla-400'
              "
              @click="selectAttr(group.name, opt.value)"
            >
              {{ opt.value }}
            </button>
          </div>
        </div>

        <div
          class="flex items-center gap-3 rounded-xl border border-ucla-100 p-1"
          :class="{ 'pointer-events-none opacity-50': !canAddToCart }"
        >
          <Button
            variant="ghost"
            size="icon"
            :disabled="!canAddToCart || quantity <= 1"
            @click="quantity > 1 && quantity--"
            aria-label="Reducir cantidad"
          >
            <Minus class="size-4" />
          </Button>
          <span class="min-w-8 text-center text-sm font-medium tabular-nums">
            {{ quantity }}
          </span>
          <Button
            variant="ghost"
            size="icon"
            :disabled="!canAddToCart || quantity >= 99"
            @click="quantity < 99 && quantity++"
            aria-label="Aumentar cantidad"
          >
            <Plus class="size-4" />
          </Button>
        </div>

        <Button
          size="lg"
          class="w-full sm:w-auto"
          :disabled="!canAddToCart"
          @click="addToCart"
        >
          <ShoppingCart class="size-4" />
          {{ canAddToCart ? 'Agregar al carrito' : 'Producto agotado' }}
        </Button>
      </div>
    </div>

    <div v-else class="mt-16 text-center">
      <p class="text-sm text-ucla-900/40">Producto no encontrado</p>
      <Button variant="outline" class="mt-4" as="router-link" to="/productos">
        <ArrowLeft class="size-4" />
        Ver catálogo
      </Button>
    </div>
  </div>
</template>
