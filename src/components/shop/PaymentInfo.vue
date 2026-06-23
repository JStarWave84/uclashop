<script setup>
import { computed } from 'vue'
import { Copy } from '@lucide/vue'
import { formatPrice, formatVes } from '@/lib/utils'

const props = defineProps({
  account: { type: Object, required: true },
  total: { type: Number, default: null },
  showTotal: { type: Boolean, default: false },
  instructions: { type: String, default: '' },
  exchangeRate: { type: Number, default: null },
})

function copy(text) {
  if (!navigator?.clipboard) return
  navigator.clipboard.writeText(text).catch(() => {})
}

const vesTotal = computed(() => {
  if (props.total === null || props.exchangeRate === null) return null
  return formatVes(props.total * props.exchangeRate)
})
</script>

<template>
  <div class="rounded-xl border border-ucla-100 bg-ucla-50/50 p-5">
    <h2
      v-if="$slots.title"
      class="text-center text-lg font-semibold text-ucla-900"
      style="font-family: var(--font-display)"
    >
      <slot name="title" />
    </h2>

    <p v-if="total !== null" class="mt-2 text-center text-sm text-ucla-900/50">
      Realizá el pago por el
      <span class="font-semibold text-ucla-700">{{ formatPrice(total) }}</span>
      exacto a través de pago móvil o transferencia.
    </p>

    <dl class="mt-4 space-y-3 rounded-xl border border-ucla-200 bg-white p-5">
      <div class="flex items-center justify-between">
        <dt class="text-sm text-ucla-900/50">Banco</dt>
        <dd class="text-sm font-medium text-ucla-900">{{ account.bank }}</dd>
      </div>
      <div class="flex items-center justify-between">
        <dt class="text-sm text-ucla-900/50">Titular</dt>
        <dd class="text-sm font-medium text-ucla-900">{{ account.holder || '—' }}</dd>
      </div>
      <div class="flex items-center justify-between">
        <dt class="text-sm text-ucla-900/50">Teléfono</dt>
        <dd class="flex items-center gap-2 text-sm font-medium text-ucla-900">
          {{ account.phone }}
          <button
            class="shrink-0 text-ucla-900/30 transition-colors hover:text-ucla-600"
            @click="copy(account.phone)"
            aria-label="Copiar teléfono"
          >
            <Copy class="size-3.5" />
          </button>
        </dd>
      </div>
      <div class="flex items-center justify-between">
        <dt class="text-sm text-ucla-900/50">CI / RIF</dt>
        <dd class="flex items-center gap-2 text-sm font-medium text-ucla-900">
          {{ account.ci }}
          <button
            class="shrink-0 text-ucla-900/30 transition-colors hover:text-ucla-600"
            @click="copy(account.ci)"
            aria-label="Copiar CI"
          >
            <Copy class="size-3.5" />
          </button>
        </dd>
      </div>
      <div v-if="showTotal" class="border-t border-ucla-100 pt-3">
        <div class="flex items-center justify-between">
          <dt class="text-sm font-semibold text-ucla-900">Total a pagar</dt>
          <dd class="text-lg font-semibold text-ucla-700">
            {{ formatPrice(total) }}
          </dd>
        </div>
        <p v-if="vesTotal" class="mt-0.5 text-right text-md text-ucla-900/80">≈ {{ vesTotal }}</p>
      </div>
    </dl>

    <div v-if="instructions" class="mt-4 rounded-lg bg-ucla-gold/10 p-4 text-center">
      <p class="text-sm text-ucla-900/70">{{ instructions }}</p>
    </div>
  </div>
</template>
