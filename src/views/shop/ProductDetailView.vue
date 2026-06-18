<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { useCartStore } from '@/stores/cart'
import { ShoppingCart, Minus, Plus, ArrowLeft, Package, ImageOff } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { formatPrice } from '@/lib/utils'
import PaymentInfo from '@/components/shop/PaymentInfo.vue'

const route = useRoute()
const cart = useCartStore()

const loading = ref(true)
const product = ref(null)
const paymentAccount = ref(null)
const quantity = ref(1)

function productImageUrl(path) {
  if (!path) return null
  const {
    data: { publicUrl },
  } = supabase.storage.from('product-images').getPublicUrl(path)
  return publicUrl
}

onMounted(async () => {
  const [productRes, paymentRes] = await Promise.all([
    supabase.from('products').select('*').eq('id', route.params.id).single(),
    supabase.from('payment_accounts').select('*').eq('is_active', true),
  ])

  if (productRes.error) {
    toast.error('Error al cargar el producto')
  } else {
    product.value = productRes.data
  }

  if (paymentRes.error) {
    toast.error('Error al cargar información de pago')
  } else if (paymentRes.data?.length) {
    paymentAccount.value = {
      ...paymentRes.data[0],
      holder: paymentRes.data[0].holder_name,
    }
  }

  loading.value = false
})

function addToCart() {
  if (!product.value) return
  cart.addItem(product.value, quantity.value)
  quantity.value = 1
}

const stockLabel = computed(() => {
  if (!product.value) return ''
  if (product.value.stock > 10) return 'Disponible'
  if (product.value.stock > 0) return `Quedan ${product.value.stock}`
  if (product.value.allow_backorder) return 'Acepta backorder'
  return 'Agotado'
})

const stockVariant = computed(() => {
  if (!product.value) return ''
  if (product.value.stock > 0) return 'text-emerald-600 bg-emerald-50'
  if (product.value.allow_backorder) return 'text-ucla-gold bg-ucla-gold/10'
  return 'text-red-500 bg-red-50'
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
          {{ formatPrice(product.price) }}
        </span>

        <div class="flex items-center gap-3 rounded-xl border border-ucla-100 p-1">
          <Button
            variant="ghost"
            size="icon"
            :disabled="quantity <= 1"
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
            :disabled="quantity >= 99"
            @click="quantity < 99 && quantity++"
            aria-label="Aumentar cantidad"
          >
            <Plus class="size-4" />
          </Button>
        </div>

        <Button size="lg" class="w-full sm:w-auto" @click="addToCart">
          <ShoppingCart class="size-4" />
          Agregar al carrito
        </Button>

        <PaymentInfo v-if="paymentAccount" :account="paymentAccount" class="!p-0 !border-0" />
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
