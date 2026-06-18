<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { ArrowLeft, Save, Copy, ImageIcon } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { statusColors, statusLabels } from '@/lib/mock'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'

const route = useRoute()
const router = useRouter()

const order = ref(null)
const items = ref([])
const delivery = ref(null)
const newStatus = ref('pending_payment')
const receiptDialogOpen = ref(false)
const receiptSignedUrl = ref('')

async function fetchOrder() {
  const id = route.params.id
  const { data, error } = await supabase.from('orders').select('*').eq('id', id).single()
  if (error) {
    console.error('fetchOrder', error)
    toast.error('No se pudo cargar la orden')
    return
  }
  order.value = data
  newStatus.value = data.status

  const { data: oi, error: e2 } = await supabase.from('order_items').select('*').eq('order_id', id)
  if (!e2) items.value = oi || []

  const { data: d } = await supabase.from('deliveries').select('*').eq('order_id', id).maybeSingle()
  if (d) delivery.value = d
}

onMounted(fetchOrder)

async function handleStatusUpdate() {
  if (!order.value) return
  const { error } = await supabase
    .from('orders')
    .update({ status: newStatus.value })
    .eq('id', order.value.id)
  if (error) {
    console.error('update status', error)
    toast.error('No se pudo actualizar el estado')
  } else {
    order.value.status = newStatus.value
    toast.success('Estado actualizado')
  }
}

async function openReceipt() {
  if (!order.value?.payment_receipt_url) return
  const { data, error } = await supabase.storage
    .from('receipts')
    .createSignedUrl(order.value.payment_receipt_url, 3600)
  if (error) {
    console.error('signedUrl', error)
    toast.error('No se pudo cargar el comprobante')
    return
  }
  receiptSignedUrl.value = data.signedUrl
  receiptDialogOpen.value = true
}

function copy(text) {
  if (!navigator?.clipboard) return
  navigator.clipboard.writeText(text).catch(() => {})
}
</script>

<template>
  <div v-if="order" class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
    <router-link
      to="/admin/ordenes"
      class="inline-flex items-center gap-1.5 text-sm text-neutral-500 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver a órdenes
    </router-link>

    <div class="mt-4 flex items-start justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Orden {{ order.id }}
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ new Date(order.created_at).toLocaleDateString('es-ES', { dateStyle: 'long' }) }}
        </p>
      </div>
      <span
        class="rounded-full border px-3 py-1 text-xs font-medium capitalize"
        :class="statusColors[order.status] || ''"
      >
        {{ statusLabels[order.status] || order.status }}
      </span>
    </div>

    <div class="mt-8 grid gap-6 lg:grid-cols-2">
      <div class="rounded-xl border border-neutral-200 bg-white p-5">
        <h2 class="text-sm font-semibold text-neutral-900">Datos del cliente</h2>
        <dl class="mt-3 space-y-2 text-sm">
          <div class="flex justify-between">
            <dt class="text-neutral-500">Nombre</dt>
            <dd class="font-medium text-neutral-900">
              {{ order.customer_first_name }} {{ order.customer_last_name }}
            </dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-neutral-500">CI</dt>
            <dd class="font-medium text-neutral-900">{{ order.customer_ci || '-' }}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-neutral-500">Teléfono</dt>
            <dd class="flex items-center gap-1.5 font-medium text-neutral-900">
              {{ order.customer_phone }}
              <button
                @click="copy(order.customer_phone)"
                class="text-neutral-300 hover:text-ucla-600"
              >
                <Copy class="size-3.5" />
              </button>
            </dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-neutral-500">Email</dt>
            <dd class="font-medium text-neutral-900">{{ order.customer_email || '-' }}</dd>
          </div>
        </dl>
      </div>

      <div class="rounded-xl border border-neutral-200 bg-white p-5">
        <h2 class="text-sm font-semibold text-neutral-900">Gestión de estado</h2>
        <div class="mt-3 flex items-center gap-3">
          <select
            v-model="newStatus"
            class="h-9 flex-1 rounded-md border border-input bg-transparent px-3 text-sm transition-colors focus:border-ring focus:ring-3 focus:ring-ring/50 focus:outline-none"
          >
            <option v-for="(label, key) in statusLabels" :key="key" :value="key">
              {{ label }}
            </option>
          </select>
          <Button size="sm" @click="handleStatusUpdate">
            <Save class="size-4" />
            Actualizar
          </Button>
        </div>
      </div>
    </div>

    <div class="mt-6 rounded-xl border border-neutral-200 bg-white p-5">
      <h2 class="text-sm font-semibold text-neutral-900">Productos</h2>
      <table class="mt-3 w-full text-left text-sm">
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
            <td class="py-2 font-medium text-neutral-900">{{ item.product_name_snapshot }}</td>
            <td class="py-2 text-neutral-600 tabular-nums">
              <PriceDisplay :price="item.price_snapshot" />
            </td>
            <td class="py-2 text-neutral-600 tabular-nums">{{ item.quantity }}</td>
            <td class="py-2 text-right font-semibold text-neutral-700 tabular-nums">
              <PriceDisplay :price="item.price_snapshot * item.quantity" />
            </td>
          </tr>
        </tbody>
        <tfoot>
          <tr class="border-t border-neutral-100">
            <td colspan="3" class="pt-3 text-sm font-semibold text-neutral-900">Total</td>
            <td class="pt-3 text-right text-lg font-semibold text-ucla-700 tabular-nums">
              <PriceDisplay :price="order.total" />
            </td>
          </tr>
        </tfoot>
      </table>
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-2">
      <div class="rounded-xl border border-neutral-200 bg-white p-5">
        <h2 class="text-sm font-semibold text-neutral-900">Pago</h2>
        <dl class="mt-3 space-y-2 text-sm">
          <div class="flex justify-between">
            <dt class="text-neutral-500">Referencia</dt>
            <dd class="font-medium text-neutral-900">{{ order.payment_reference || '—' }}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-neutral-500">Comprobante</dt>
            <dd>
              <button
                v-if="order.payment_receipt_url"
                class="inline-flex items-center gap-1.5 font-medium text-ucla-600 hover:text-ucla-700 hover:underline"
                @click="openReceipt"
              >
                <ImageIcon class="size-3.5" />
                Ver comprobante
              </button>
              <span v-else class="text-neutral-400">Sin subir</span>
            </dd>
          </div>
        </dl>
      </div>

      <div class="rounded-xl border border-neutral-200 bg-white p-5">
        <h2 class="text-sm font-semibold text-neutral-900">Entrega</h2>
        <dl v-if="delivery" class="mt-3 space-y-2 text-sm">
          <div class="flex justify-between">
            <dt class="text-neutral-500">Estado</dt>
            <dd>
              <span
                class="rounded-full border px-2 py-0.5 text-[10px] font-medium"
                :class="statusColors[delivery.status] || ''"
              >
                {{ statusLabels[delivery.status] || delivery.status }}
              </span>
            </dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-neutral-500">Notas</dt>
            <dd class="text-right text-neutral-700">{{ delivery.notes || '—' }}</dd>
          </div>
        </dl>
        <p v-else class="mt-3 text-sm text-neutral-400">Sin seguimiento de entrega</p>
      </div>
    </div>
  </div>

  <div v-else class="p-8 text-center text-sm text-neutral-400">Orden no encontrada</div>

  <Dialog v-model:open="receiptDialogOpen">
    <DialogContent class="sm:max-w-2xl">
      <DialogHeader>
        <DialogTitle>Comprobante de pago</DialogTitle>
      </DialogHeader>
      <div class="flex items-center justify-center overflow-hidden rounded-lg bg-neutral-50">
        <img
          v-if="receiptSignedUrl"
          :src="receiptSignedUrl"
          alt="Comprobante de pago"
          class="max-h-[70vh] w-full object-contain"
        />
      </div>
    </DialogContent>
  </Dialog>
</template>
