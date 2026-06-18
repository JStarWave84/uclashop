<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { useCartStore } from '@/stores/cart'
import { ShoppingCart, ArrowLeft } from '@lucide/vue'
import CheckoutForm from '@/components/shop/CheckoutForm.vue'
import OrderSummary from '@/components/shop/OrderSummary.vue'
import PaymentInfo from '@/components/shop/PaymentInfo.vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { useExchangeRate } from '@/composables/useExchangeRate'

const router = useRouter()
const cart = useCartStore()
const { rate: exchangeRate, loading: rateLoading } = useExchangeRate()

const paymentAccounts = ref([])

onMounted(async () => {
  const { data } = await supabase
    .from('payment_accounts')
    .select('*')
    .eq('is_active', true)
    .order('created_at')
  if (data) paymentAccounts.value = data
})

async function placeOrder(data) {
  // Create order + order_items in DB, upload receipt if provided
  const items = cart.items.map((i) => ({
    product_id: i.id,
    quantity: i.quantity,
    product_name_snapshot: i.name,
    price_snapshot: i.price,
  }))
  const total = cart.totalPrice

  try {
    // insert order (anonymous allowed by RLS for INSERT)
    const { data: orderData, error: orderErr } = await supabase
      .from('orders')
      .insert([
        {
          total,
          customer_first_name: data.first_name,
          customer_last_name: data.last_name,
          customer_ci: data.ci,
          customer_phone: data.phone,
          customer_email: data.email,
          payment_reference: data.payment_reference || null,
        },
      ])
      .select('id')
      .single()

    if (orderErr) {
      console.error('createOrder', orderErr)
      toast.error('No se pudo crear la orden')
      return
    }

    const orderId = orderData.id

    // insert order_items
    const itemsToInsert = items.map((it) => ({
      order_id: orderId,
      product_id: it.product_id,
      product_name_snapshot: it.product_name_snapshot,
      price_snapshot: it.price_snapshot,
      quantity: it.quantity,
    }))
    const { error: oiErr } = await supabase.from('order_items').insert(itemsToInsert)
    if (oiErr) {
      console.error('insertOrderItems', oiErr)
      toast.error('No se pudo crear los items de la orden')
      return
    }

    if (data.receipt_file) {
      try {
        const file = data.receipt_file
        const ext = file.name.split('.').pop()
        const path = `${orderId}/${Date.now()}.${ext}`
        const { error: uploadErr } = await supabase.storage
          .from('receipts')
          .upload(path, file, { upsert: true })
        if (uploadErr) {
          console.error('uploadReceipt', uploadErr)
          toast.error('La orden se creó, pero no se pudo subir el comprobante')
        } else {
          await supabase.from('orders').update({ payment_receipt_url: path }).eq('id', orderId)
        }
      } catch (e) {
        console.error('receipt handling', e)
      }
    }

    toast.success('Orden creada correctamente')
    cart.clearCart()
    router.push(`/orden/${orderId}/confirmacion`)
  } catch (e) {
    console.error(e)
    toast.error('Error creando la orden')
  }
}
</script>

<template>
  <div class="mx-auto max-w-5xl px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
    <router-link
      to="/carrito"
      class="inline-flex items-center gap-1.5 text-sm text-ucla-900/50 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver al carrito
    </router-link>

    <h1
      class="mt-4 text-3xl font-semibold tracking-tight text-ucla-900 sm:text-4xl"
      style="font-family: var(--font-display)"
    >
      Finalizar pedido
    </h1>

    <div v-if="cart.items.length === 0" class="mt-12 text-center">
      <ShoppingCart class="mx-auto size-10 text-ucla-900/20" />
      <p class="mt-3 text-sm text-ucla-900/40">No hay productos en el carrito</p>
      <Button variant="outline" class="mt-4" as="router-link" to="/productos">
        Explorar productos
      </Button>
    </div>

    <div v-else class="mt-8 grid gap-8 lg:grid-cols-5 lg:gap-12">
      <div class="lg:col-span-3">
        <CheckoutForm @submit="placeOrder" />
      </div>

      <aside class="flex flex-col gap-6 lg:col-span-2">
        <OrderSummary :items="cart.items" :total="cart.totalPrice" />

        <PaymentInfo
          v-for="acct in paymentAccounts"
          :key="acct.id"
          :account="{ bank: acct.bank, holder: acct.holder_name, phone: acct.phone, ci: acct.ci }"
          :total="cart.totalPrice"
          :exchangeRate="exchangeRate"
          showTotal
        >
          <template #title>{{ acct.name }}</template>
        </PaymentInfo>
      </aside>
    </div>
  </div>
</template>
