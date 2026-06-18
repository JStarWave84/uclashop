<script setup>
import { ref } from 'vue'
import { formatPrice, formatVes } from '@/lib/utils'
import { useExchangeRate } from '@/composables/useExchangeRate'

const props = defineProps({
  price: { type: Number, required: true },
  className: { type: String, default: '' },
})

const { rate } = useExchangeRate()
const show = ref(false)
</script>

<template>
  <span
    class="relative cursor-help tabular-nums"
    :class="className"
    @mouseenter="show = true"
    @mouseleave="show = false"
    @focusin="show = true"
    @focusout="show = false"
  >
    {{ formatPrice(price) }}
    <span
      v-if="show && rate"
      class="absolute bottom-full left-1/2 mb-1.5 -translate-x-1/2 whitespace-nowrap rounded-lg border border-ucla-100 bg-white px-2 py-1 text-xs shadow-sm"
      role="tooltip"
    >
      {{ formatVes(price * rate) }}
    </span>
  </span>
</template>
