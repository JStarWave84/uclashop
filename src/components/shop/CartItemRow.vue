<script setup>
import { Button } from '@/components/ui/button'
import { useCartStore } from '@/stores/cart'
import { Minus, Plus, Trash2 } from '@lucide/vue'
import { formatPrice } from '@/lib/utils'

const props = defineProps({
  item: { type: Object, required: true },
  compact: { type: Boolean, default: false },
})

const cart = useCartStore()
</script>

<template>
  <div class="flex items-center gap-3 py-3" :class="{ 'sm:gap-4': !compact }">
    <div
      v-if="!compact"
      class="flex size-12 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-ucla-50 to-ucla-100 sm:size-14"
    >
      <span class="text-sm font-semibold tracking-tight text-ucla-200/70"> UCLA </span>
    </div>

    <div class="min-w-0 flex-1">
      <p class="truncate text-sm font-medium text-ucla-900">
        {{ item.name }}
      </p>
      <p v-if="compact" class="text-xs text-ucla-900/40">{{ formatPrice(item.price) }} c/u</p>
      <p v-else class="mt-0.5 text-xs text-ucla-900/40">{{ formatPrice(item.price) }} c/u</p>
    </div>

    <div class="flex items-center gap-1 rounded-lg border border-ucla-100 p-0.5">
      <Button
        variant="ghost"
        size="icon-sm"
        :disabled="item.quantity <= 1"
        @click="cart.updateQty(item.id, item.quantity - 1)"
        aria-label="Reducir cantidad"
      >
        <Minus class="size-3" />
      </Button>
      <span class="min-w-5 text-center text-xs font-medium tabular-nums">
        {{ item.quantity }}
      </span>
      <Button
        variant="ghost"
        size="icon-sm"
        :disabled="item.quantity >= 99"
        @click="cart.updateQty(item.id, item.quantity + 1)"
        aria-label="Aumentar cantidad"
      >
        <Plus class="size-3" />
      </Button>
    </div>

    <p
      class="min-w-[4rem] text-right text-sm font-semibold text-ucla-700 tabular-nums"
      :class="{ 'text-xs': compact }"
    >
      {{ formatPrice(item.price * item.quantity) }}
    </p>

    <Button
      variant="ghost"
      size="icon"
      class="shrink-0 text-ucla-900/20 transition-colors hover:text-red-400"
      @click="cart.removeItem(item.id)"
      aria-label="Eliminar producto"
    >
      <Trash2 class="size-3.5" />
    </Button>
  </div>
</template>
