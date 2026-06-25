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
  if (cart.items.length === 0) return

  const productIds = cart.items.map((i) => i.id)
  const { data: linked } = await supabase
    .from('product_payment_accounts')
    .select('payment_account_id, payment_accounts(*)')
    .in('product_id', productIds)
  if (linked && linked.length > 0) {
    const seen = new Set()
    paymentAccounts.value = linked
      .filter((r) => {
        if (seen.has(r.payment_account_id)) return false
        seen.add(r.payment_account_id)
        return true
      })
      .map((r) => r.payment_accounts)
    return
  }

  const { data: settings } = await supabase
    .from('payment_settings')
    .select('*')
    .limit(1)
    .single()
  if (settings && (settings.bank || settings.phone)) {
    paymentAccounts.value = [{
      id: 'global',
      name: settings.name || 'Pago móvil',
      bank: settings.bank,
      holder_name: settings.holder_name,
      phone: settings.phone,
      ci: settings.ci,
    }]
  }
})

async function placeOrder(data) {
  const items = cart.items.map((i) => ({
    product_id: i.id,
    quantity: i.quantity,
    product_name_snapshot: i.name,
    price_snapshot: i.price,
  }))
  const total = cart.totalPrice

  try {
    const { data: result, error: rpcErr } = await supabase.rpc('place_order', {
      p_total: total,
      p_first_name: data.first_name,
      p_last_name: data.last_name,
      p_ci: data.ci,
      p_phone: data.phone,
      p_email: data.email,
      p_payment_reference: data.payment_reference || null,
      p_items: items,
    })

    if (rpcErr) {
      console.error('placeOrder', rpcErr)
      toast.error('No se pudo crear la orden')
      return
    }

    const orderId = result.id

    if (data.receipt_file) {
      const file = data.receipt_file
      const ext = file.name.split('.').pop()
      const path = `${orderId}/${Date.now()}.${ext}`
      await supabase.storage.from('receipts').upload(path, file, { upsert: true }).catch(() => {
        toast.error('La orden se creó, pero no se pudo subir el comprobante')
      })
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
      <Button variant="outline" class="mt-4" @click="router.push('/productos')">
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
