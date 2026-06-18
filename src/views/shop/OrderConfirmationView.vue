<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Check, ArrowLeft, MessageCircle, Copy } from '@lucide/vue'
import { formatPrice } from '@/lib/utils'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const route = useRoute()
const router = useRouter()
const orderId = route.params.id

const orderData = ref(null)

onMounted(async () => {
  if (!orderId) return
  const { data, error } = await supabase.from('orders').select('*').eq('id', orderId).single()
  if (error) {
    console.error('loadOrderConfirmation', error)
    toast.error('No se pudo cargar la orden')
    return
  }
  const { data: items, error: oiErr } = await supabase
    .from('order_items')
    .select('*')
    .eq('order_id', orderId)
  if (oiErr) {
    console.error('loadOrderItems', oiErr)
  }
  orderData.value = {
    id: data.id,
    total: data.total,
    payment: { reference: data.payment_reference, receipt_url: data.payment_receipt_url },
    customer: {
      first_name: data.customer_first_name,
      last_name: data.customer_last_name,
      ci: data.customer_ci,
      phone: data.customer_phone,
      email: data.customer_email,
    },
    items: (items || []).map((i) => ({
      name: i.product_name_snapshot,
      price: Number(i.price_snapshot),
      quantity: i.quantity,
    })),
  }
})

const customerName = computed(() => {
  if (!orderData.value) return ''
  const { first_name, last_name } = orderData.value.customer
  return [first_name, last_name].filter(Boolean).join(' ')
})

const itemsList = computed(() => {
  if (!orderData.value) return ''
  return orderData.value.items
    .map((i) => `• ${i.name} x${i.quantity} — ${formatPrice(i.price * i.quantity)}`)
    .join('\n')
})

const waPhone = '584262617824'

const waMessage = computed(() => {
  if (!orderData.value) return ''
  const lines = [
    `*Nuevo pedido* #${orderId}`,
    '',
    `*Cliente:* ${customerName.value}`,
    `*Teléfono:* ${orderData.value.customer.phone}`,
    orderData.value.customer.ci ? `*Cédula:* ${orderData.value.customer.ci}` : '',
    orderData.value.customer.email ? `*Email:* ${orderData.value.customer.email}` : '',
    '',
    '*Productos:*',
    itemsList.value,
    '',
    `*Total:* ${formatPrice(orderData.value.total)}`,
  ]
  if (orderData.value.payment.reference) {
    lines.push('', `*Referencia:* ${orderData.value.payment.reference}`)
  }
  if (orderData.value.payment.receipt_url) {
    lines.push(`*Comprobante:* ${orderData.value.payment.receipt_url}`)
  }
  return lines.filter(Boolean).join('\n')
})

const waUrl = computed(() => `https://wa.me/${waPhone}?text=${encodeURIComponent(waMessage.value)}`)

function copyMessage() {
  navigator.clipboard?.writeText(waMessage.value).catch(() => {})
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-12 sm:px-6 sm:py-16 lg:px-8">
    <div class="text-center">
      <div class="mx-auto flex size-14 items-center justify-center rounded-full bg-emerald-50">
        <Check class="size-7 text-emerald-600" />
      </div>

      <h1
        class="mt-4 text-3xl font-semibold tracking-tight text-ucla-900 sm:text-4xl"
        style="font-family: var(--font-display)"
      >
        Pedido creado con éxito
      </h1>

      <p class="mt-2 text-sm text-ucla-900/50">
        Tu número de orden es
        <span class="font-medium text-ucla-900">#{{ orderId }}</span>
      </p>
    </div>

    <div v-if="orderData" class="mt-10 space-y-5">
      <div class="rounded-xl border border-ucla-100 bg-white p-5">
        <h2 class="text-sm font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Datos del cliente
        </h2>
        <dl class="mt-3 space-y-2 text-sm">
          <div class="flex justify-between">
            <dt class="text-ucla-900/50">Nombre</dt>
            <dd class="font-medium text-ucla-900">{{ customerName }}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-ucla-900/50">Teléfono</dt>
            <dd class="font-medium text-ucla-900">{{ orderData.customer.phone }}</dd>
          </div>
          <div v-if="orderData.customer.ci" class="flex justify-between">
            <dt class="text-ucla-900/50">Cédula</dt>
            <dd class="font-medium text-ucla-900">{{ orderData.customer.ci }}</dd>
          </div>
          <div v-if="orderData.customer.email" class="flex justify-between">
            <dt class="text-ucla-900/50">Email</dt>
            <dd class="font-medium text-ucla-900">{{ orderData.customer.email }}</dd>
          </div>
        </dl>
      </div>

      <div class="rounded-xl border border-ucla-100 bg-white p-5">
        <h2 class="text-sm font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Productos
        </h2>
        <ul class="mt-3 divide-y divide-ucla-100">
          <li v-for="item in orderData.items" :key="item.name" class="flex justify-between py-2">
            <span class="text-sm text-ucla-900/70">
              {{ item.name }}
              <span class="text-ucla-900/40">x{{ item.quantity }}</span>
            </span>
            <span class="text-sm font-medium text-ucla-700 tabular-nums">
              {{ formatPrice(item.price * item.quantity) }}
            </span>
          </li>
        </ul>
        <div class="mt-3 flex items-baseline justify-between border-t border-ucla-100 pt-3">
          <span class="text-sm font-semibold text-ucla-900">Total</span>
          <span class="text-xl font-semibold text-ucla-700 tabular-nums">
            {{ formatPrice(orderData.total) }}
          </span>
        </div>
      </div>

      <div class="rounded-xl border border-ucla-100 bg-white p-5">
        <h2 class="text-sm font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Datos del pago
        </h2>
        <dl class="mt-3 space-y-2 text-sm">
          <div v-if="orderData.payment.reference" class="flex justify-between">
            <dt class="text-ucla-900/50">Referencia</dt>
            <dd class="font-medium text-ucla-900">{{ orderData.payment.reference }}</dd>
          </div>
          <div v-if="orderData.payment.receipt_name" class="flex justify-between">
            <dt class="text-ucla-900/50">Comprobante</dt>
            <dd class="font-medium text-ucla-900">{{ orderData.payment.receipt_name }}</dd>
          </div>
          <p
            v-if="!orderData.payment.reference && !orderData.payment.receipt_name"
            class="text-xs text-ucla-900/40"
          >
            No se registraron datos de pago.
          </p>
        </dl>
      </div>
    </div>

    <div class="mt-8 text-center">
      <p class="text-sm text-ucla-900/50">
        Informá del pedido al administrador por WhatsApp para agilizar la confirmación.
      </p>

      <div class="mt-4 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
        <a :href="waUrl" target="_blank" rel="noopener noreferrer">
          <Button size="lg" class="w-full sm:w-auto">
            <MessageCircle class="size-4" />
            Notificar por WhatsApp
          </Button>
        </a>

        <Button variant="outline" size="lg" @click="copyMessage">
          <Copy class="size-4" />
          Copiar resumen
        </Button>
      </div>
    </div>

    <div class="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
      <Button variant="outline" @click="router.push('/')">
        <ArrowLeft class="size-4" />
        Volver al inicio
      </Button>
    </div>
  </div>
</template>
