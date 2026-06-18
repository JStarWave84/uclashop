<script setup>
import ProductCard from './ProductCard.vue'

defineProps({
  products: { type: Array, required: true },
  columns: { type: Number, default: 3 },
})
</script>

<template>
  <div
    class="grid gap-5"
    :class="{
      'sm:grid-cols-2': columns >= 2,
      'lg:grid-cols-3': columns >= 3,
      'lg:grid-cols-4': columns >= 4,
    }"
  >
    <ProductCard v-for="product in products" :key="product.id" :product="product" />
  </div>
</template>
