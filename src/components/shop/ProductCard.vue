<script setup>
import { Button } from '@/components/ui/button'
import { ShoppingCart } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { useCartStore } from '@/stores/cart'
import { formatPrice } from '@/lib/utils'

const props = defineProps({
  product: { type: Object, required: true },
})

const cart = useCartStore()

function imageUrl(path) {
  if (!path) return null
  const {
    data: { publicUrl },
  } = supabase.storage.from('product-images').getPublicUrl(path)
  return publicUrl
}
</script>

<template>
  <article
    class="group relative flex flex-col overflow-hidden rounded-xl border border-ucla-100 bg-white transition-all hover:shadow-md"
  >
    <div class="aspect-[4/3] overflow-hidden bg-gradient-to-br from-ucla-50 to-ucla-100">
      <img
        v-if="product.product_image_path"
        :src="imageUrl(product.product_image_path)"
        :alt="product.name"
        class="size-full object-cover transition-transform duration-300 group-hover:scale-105"
      />
      <div v-else class="flex h-full items-center justify-center">
        <span class="text-5xl font-display font-semibold tracking-tight text-ucla-200"> UCLA </span>
      </div>
    </div>

    <div class="flex flex-1 flex-col gap-2 p-4">
      <div class="flex items-start justify-between gap-2">
        <h3 class="text-sm font-medium leading-snug text-ucla-900">
          {{ product.name }}
        </h3>
        <span
          v-if="product.stock === 0"
          class="shrink-0 rounded-full bg-ucla-gold/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider text-ucla-gold"
        >
          Backorder
        </span>
      </div>

      <p class="line-clamp-2 text-xs leading-relaxed text-ucla-900/50">
        {{ product.description }}
      </p>

      <div class="mt-auto flex items-center justify-between pt-2">
        <span class="text-lg font-semibold tracking-tight text-ucla-700">
          {{ formatPrice(product.price) }}
        </span>
        <Button size="sm" @click.stop="cart.addItem(product)" aria-label="Agregar al carrito">
          <ShoppingCart class="size-3.5" />
          <span class="sr-only sm:not-sr-only">Comprar</span>
        </Button>
      </div>
    </div>

    <router-link
      :to="`/productos/${product.id}`"
      class="absolute inset-0 rounded-xl focus:outline-none focus-visible:ring-2 focus-visible:ring-ucla-500 focus-visible:ring-offset-2"
      :aria-label="'Ver detalle de ' + product.name"
    >
      <span class="sr-only">Ver detalle de {{ product.name }}</span>
    </router-link>
  </article>
</template>
