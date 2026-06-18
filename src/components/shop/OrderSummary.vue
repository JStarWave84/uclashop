<script setup>
import { formatPrice } from '@/lib/utils'

defineProps({
  items: { type: Array, required: true },
  total: { type: Number, required: true },
  showHeader: { type: Boolean, default: true },
})
</script>

<template>
  <div class="rounded-xl border border-ucla-100 bg-ucla-50/50 p-5">
    <h2 v-if="showHeader" class="text-sm font-semibold text-ucla-900">Resumen del pedido</h2>

    <ul class="divide-y divide-ucla-100" :class="{ 'mt-4': showHeader }">
      <li v-for="item in items" :key="item.id" class="flex justify-between py-2">
        <span class="text-sm text-ucla-900/70">
          {{ item.name }}
          <span class="text-ucla-900/40">x{{ item.quantity }}</span>
        </span>
        <span class="text-sm font-medium text-ucla-700 tabular-nums">
          {{ formatPrice(item.price * item.quantity) }}
        </span>
      </li>
    </ul>

    <div class="mt-4 flex items-baseline justify-between border-t border-ucla-100 pt-4">
      <span class="text-sm font-semibold text-ucla-900">Total</span>
      <span class="text-xl font-semibold text-ucla-700 tabular-nums">
        {{ formatPrice(total) }}
      </span>
    </div>
  </div>
</template>
