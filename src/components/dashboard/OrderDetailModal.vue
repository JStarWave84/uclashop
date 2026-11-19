<script setup>
import { ref, watch } from 'vue'
import { Button } from '@/components/ui/button'
import { Copy, ImageIcon, Check, XCircle, Loader2, Package } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { statusColors, statusLabels } from '@/lib/mock'
import {
  Dialog,
  DialogScrollContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  orderId: { type: String, default: null },
  initialOrder: { type: Object, default: null },
})

const emit = defineEmits(['update:open', 'updated'])

const order = ref(null)
const items = ref([])
const loading = ref(false)
const loadError = ref('')
const newStatus = ref('')
const saving = ref(false)
const rejectConfirm = ref(false)

const receiptOpen = ref(false)
const receiptUrl = ref('')
const receiptLoading = ref(false)

function resetView() {
  rejectConfirm.value = false
  receiptOpen.value = false
  receiptUrl.value = ''
  receiptLoading.value = false
}

async function loadOrder() {
  if (!props.orderId) return

  loading.value = true
  loadError.value = ''
  resetView()

  const [orderRes, itemsRes] = await Promise.all([
    supabase.from('orders').select('*').eq('id', props.orderId).single(),
    supabase.from('order_items').select('*').eq('order_id', props.orderId),
  ])

  if (orderRes.error) {
    console.error('fetchOrder', orderRes.error)
    loadError.value = 'No se pudo cargar la orden'
    loading.value = false
    return
  }

  if (itemsRes.error) {
    console.error('fetchOrderItems', itemsRes.error)
    toast.error('No se pudieron cargar los productos')
  }

  order.value = orderRes.data
  items.value = itemsRes.data || []
  newStatus.value = orderRes.data.status
  loading.value = false
}

watch(
  () => [props.open, props.orderId],
  ([isOpen, id]) => {
    if (!isOpen || !id) return

    if (order.value?.id !== id) {
      // Show the row data instantly while the full order loads.
      order.value = props.initialOrder?.id === id ? props.initialOrder : null
      items.value = []
      newStatus.value = order.value?.status || ''
      loadError.value = ''
    }

    loadOrder()
  },
  { immediate: true }
)

function copy(text) {
  if (!text || !navigator?.clipboard) return
  navigator.clipboard
    .writeText(text)
    .then(() => toast.success('Copiado'))
    .catch(() => {})
}

async function updateStatus(status) {
  if (!order.value || saving.value) return
  if (status === order.value.status) {
    rejectConfirm.value = false
    return
  }

  saving.value = true
  const { error } = await supabase
    .from('orders')
    .update({ status })
    .eq('id', order.value.id)

  if (error) {
    console.error('update status', error)
    toast.error('No se pudo actualizar el estado')
  } else {
    order.value = { ...order.value, status }
    newStatus.value = status
    emit('updated', { ...order.value })
    toast.success(`Estado actualizado a "${statusLabels[status] || status}"`)
  }

  saving.value = false
  rejectConfirm.value = false
}

function normalizeReceiptPath(raw) {
  if (!raw) return null
  if (raw.startsWith('storage://receipts/')) return raw.replace('storage://receipts/', '')
  return raw
}

async function toggleReceipt() {
  if (receiptOpen.value) {
    receiptOpen.value = false
    return
  }

  const path = normalizeReceiptPath(order.value?.payment_receipt_url)
  if (!path) return

  if (/^https?:\/\//.test(path)) {
    receiptUrl.value = path
    receiptOpen.value = true
    return
  }

  receiptLoading.value = true
  const { data, error } = await supabase.storage.from('receipts').createSignedUrl(path, 3600)
  receiptLoading.value = false

  if (error) {
    console.error('signedUrl', error)
    toast.error('El comprobante no se encontró en el almacenamiento')
    return
  }

  receiptUrl.value = data.signedUrl
  receiptOpen.value = true
}

function itemVariantLabel(item) {
  const attrs = item.variant_attributes_snapshot
  if (!attrs || typeof attrs !== 'object') return ''
  const entries = Object.entries(attrs)
  if (!entries.length) return ''
  return entries.map(([key, value]) => `${key} ${value}`).join(' · ')
}

function formatDate(value) {
  if (!value) return ''
  return new Date(value).toLocaleDateString('es-ES', { dateStyle: 'long' })
}
</script>

<template>
  <Dialog :open="open" @update:open="(value) => emit('update:open', value)">
    <DialogScrollContent class="sm:max-w-4xl">
      <DialogHeader>
        <DialogTitle class="flex flex-wrap items-baseline gap-2 pr-6">
          <span style="font-family: var(--font-display)">Orden</span>
          <span class="break-all font-mono text-sm font-normal text-neutral-500">
            {{ orderId }}
          </span>
        </DialogTitle>
        <DialogDescription>
          {{ order ? formatDate(order.created_at) : 'Cargando orden...' }}
        </DialogDescription>
      </DialogHeader>

      <div v-if="loading && !order" class="flex items-center justify-center gap-2 py-16 text-sm text-neutral-500">
        <Loader2 class="size-4 animate-spin" />
        Cargando orden...
      </div>

      <div v-else-if="loadError" class="py-16 text-center text-sm text-neutral-500">
        {{ loadError }}
      </div>

      <template v-else-if="order">
        <div class="flex flex-wrap items-center gap-2">
          <span
            class="rounded-full border px-2.5 py-0.5 text-[11px] font-medium capitalize"
            :class="statusColors[order.status] || ''"
          >
            {{ statusLabels[order.status] || order.status }}
          </span>
          <span class="text-xs text-neutral-400">
            {{ items.length }} {{ items.length === 1 ? 'producto' : 'productos' }}
          </span>
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <!-- Cliente -->
          <div class="rounded-xl border border-neutral-200 bg-white p-5">
            <h2 class="text-sm font-semibold text-neutral-900">Datos del cliente</h2>
            <dl class="mt-3 space-y-2 text-sm">
              <div class="flex justify-between gap-4">
                <dt class="text-neutral-500">Nombre</dt>
                <dd class="text-right font-medium text-neutral-900">
                  {{ order.customer_first_name }} {{ order.customer_last_name }}
                </dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-neutral-500">CI</dt>
                <dd class="font-medium text-neutral-900">{{ order.customer_ci || '-' }}</dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-neutral-500">Teléfono</dt>
                <dd class="flex items-center gap-1.5 font-medium text-neutral-900">
                  {{ order.customer_phone }}
                  <button
                    type="button"
                    class="text-neutral-300 transition-colors hover:text-ucla-600"
                    aria-label="Copiar teléfono"
                    @click="copy(order.customer_phone)"
                  >
                    <Copy class="size-3.5" />
                  </button>
                </dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="shrink-0 text-neutral-500">Email</dt>
                <dd class="break-all text-right font-medium text-neutral-900">
                  {{ order.customer_email || '-' }}
                </dd>
              </div>
            </dl>
          </div>

          <!-- Acciones -->
          <div class="rounded-xl border border-neutral-200 bg-white p-5">
            <h2 class="text-sm font-semibold text-neutral-900">Gestión de estado</h2>

            <div class="mt-3 flex flex-wrap gap-2">
              <Button
                size="sm"
                class="bg-emerald-600 text-white hover:bg-emerald-700"
                :disabled="saving || order.status === 'paid'"
                @click="updateStatus('paid')"
              >
                <Check class="size-4" />
                Aprobar pago
              </Button>
              <Button
                size="sm"
                variant="outline"
                class="border-red-200 text-red-600 hover:bg-red-50 hover:text-red-700"
                :disabled="saving || order.status === 'rejected'"
                @click="rejectConfirm = true"
              >
                <XCircle class="size-4" />
                Rechazar
              </Button>
            </div>

            <div
              v-if="rejectConfirm"
              class="mt-3 rounded-lg border border-red-200 bg-red-50 p-3 text-xs text-red-700"
            >
              <p class="font-medium">¿Rechazar esta orden?</p>
              <p class="mt-1 text-red-600/80">El estado cambiará a "Rechazada".</p>
              <div class="mt-2.5 flex gap-2">
                <Button
                  size="sm"
                  class="bg-red-600 text-white hover:bg-red-700"
                  :disabled="saving"
                  @click="updateStatus('rejected')"
                >
                  <Loader2 v-if="saving" class="size-3.5 animate-spin" />
                  Sí, rechazar
                </Button>
                <Button size="sm" variant="ghost" :disabled="saving" @click="rejectConfirm = false">
                  Cancelar
                </Button>
              </div>
            </div>

            <div class="mt-4 border-t border-neutral-100 pt-4">
              <label class="mb-1.5 block text-xs font-medium text-neutral-500">
                Cambiar estado
              </label>
              <div class="flex items-center gap-2">
                <Select v-model="newStatus" :disabled="saving">
                  <SelectTrigger class="flex-1">
                    <SelectValue placeholder="Seleccionar estado..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem v-for="(label, key) in statusLabels" :key="key" :value="key">
                      {{ label }}
                    </SelectItem>
                  </SelectContent>
                </Select>
                <Button
                  size="sm"
                  :disabled="saving || newStatus === order.status"
                  @click="updateStatus(newStatus)"
                >
                  <Loader2 v-if="saving" class="size-4 animate-spin" />
                  Guardar
                </Button>
              </div>
            </div>
          </div>
        </div>

        <!-- Productos -->
        <div class="rounded-xl border border-neutral-200 bg-white p-5">
          <h2 class="text-sm font-semibold text-neutral-900">Productos</h2>

          <div v-if="items.length" class="mt-3 overflow-x-auto">
            <table class="w-full min-w-[520px] text-left text-sm">
              <thead>
                <tr class="border-b border-neutral-100 text-neutral-500">
                  <th class="pb-2 font-medium">Producto</th>
                  <th class="pb-2 font-medium">Precio</th>
                  <th class="pb-2 font-medium">Cantidad</th>
                  <th class="pb-2 text-right font-medium">Subtotal</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-neutral-50">
                <tr v-for="item in items" :key="item.id">
                  <td class="py-2 font-medium text-neutral-900">
                    {{ item.product_name_snapshot }}
                    <span
                      v-if="itemVariantLabel(item)"
                      class="block text-xs font-normal text-ucla-600"
                    >
                      {{ itemVariantLabel(item) }}
                    </span>
                  </td>
                  <td class="py-2 text-neutral-600 tabular-nums">
                    <PriceDisplay :price="Number(item.price_snapshot)" />
                  </td>
                  <td class="py-2 text-neutral-600 tabular-nums">{{ item.quantity }}</td>
                  <td class="py-2 text-right font-semibold text-neutral-700 tabular-nums">
                    <PriceDisplay :price="Number(item.price_snapshot) * item.quantity" />
                  </td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="border-t border-neutral-100">
                  <td colspan="3" class="pt-3 text-sm font-semibold text-neutral-900">Total</td>
                  <td class="pt-3 text-right text-lg font-semibold text-ucla-700 tabular-nums">
                    <PriceDisplay :price="Number(order.total)" />
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>

          <div v-else class="mt-4 flex items-center gap-2 text-sm text-neutral-400">
            <Package class="size-4" />
            Sin productos registrados
          </div>
        </div>

        <!-- Pago -->
        <div class="rounded-xl border border-neutral-200 bg-white p-5">
          <h2 class="text-sm font-semibold text-neutral-900">Pago</h2>
          <dl class="mt-3 space-y-2 text-sm">
            <div class="flex justify-between gap-4">
              <dt class="text-neutral-500">Referencia</dt>
              <dd class="font-medium text-neutral-900">{{ order.payment_reference || '—' }}</dd>
            </div>
            <div class="flex justify-between gap-4">
              <dt class="text-neutral-500">Comprobante</dt>
              <dd>
                <button
                  v-if="order.payment_receipt_url"
                  type="button"
                  class="inline-flex items-center gap-1.5 font-medium text-ucla-600 hover:text-ucla-700 hover:underline disabled:opacity-60"
                  :disabled="receiptLoading"
                  @click="toggleReceipt"
                >
                  <Loader2 v-if="receiptLoading" class="size-3.5 animate-spin" />
                  <ImageIcon v-else class="size-3.5" />
                  {{ receiptOpen ? 'Ocultar comprobante' : 'Ver comprobante' }}
                </button>
                <span v-else class="text-neutral-400">Sin subir</span>
              </dd>
            </div>
          </dl>

          <div
            v-if="receiptOpen && receiptUrl"
            class="mt-4 flex max-h-[60vh] items-center justify-center overflow-auto rounded-lg bg-neutral-50"
          >
            <img
              :src="receiptUrl"
              alt="Comprobante de pago"
              class="max-h-[60vh] w-full object-contain"
            />
          </div>
        </div>
      </template>
    </DialogScrollContent>
  </Dialog>
</template>
