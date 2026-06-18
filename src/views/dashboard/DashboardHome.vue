<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Package, Receipt, Plus, ArrowRight, ClipboardList } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { statusColors, statusLabels } from '@/lib/mock'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'

const router = useRouter()

const recentOrders = ref([])
const stats = ref({ total: 0, pending_payment: 0, paid: 0, in_delivery: 0 })
const loading = ref(false)

async function fetchRecentOrders() {
  loading.value = true
  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(5)
  loading.value = false
  if (error) {
    console.error('fetchRecentOrders', error)
    recentOrders.value = []
    toast.error('Error cargando órdenes recientes')
    return
  }
  recentOrders.value = data || []
}

async function fetchStats() {
  // Fetch counts per status
  const statuses = ['pending_payment', 'paid', 'in_delivery', 'delivered', 'rejected']
  try {
    const { count: total } = await supabase
      .from('orders')
      .select('id', { count: 'exact', head: true })
    stats.value.total = total || 0
  } catch (e) {
    stats.value.total = 0
  }

  for (const s of statuses) {
    try {
      const { count } = await supabase
        .from('orders')
        .select('id', { count: 'exact', head: true })
        .eq('status', s)
      if (s === 'pending_payment') stats.value.pending_payment = count || 0
      if (s === 'paid') stats.value.paid = count || 0
      if (s === 'in_delivery') stats.value.in_delivery = count || 0
    } catch (e) {
      console.error('fetchStats', e)
      toast.error('Error cargando estadísticas')
    }
  }
}

onMounted(async () => {
  await fetchRecentOrders()
  await fetchStats()
})

const statCards = computed(() => [
  {
    label: 'Órdenes totales',
    value: stats.value.total,
    icon: ClipboardList,
    color: 'text-ucla-600 bg-ucla-50',
  },
  {
    label: 'Pendientes de pago',
    value: stats.value.pending_payment,
    icon: Receipt,
    color: 'text-amber-600 bg-amber-50',
  },
  { label: 'Pagadas', value: stats.value.paid, icon: Package, color: 'text-sky-600 bg-sky-50' },
  {
    label: 'En entrega',
    value: stats.value.in_delivery,
    icon: Package,
    color: 'text-blue-600 bg-blue-50',
  },
])
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex items-end justify-between">
      <div>
        <h1
          class="text-2xl font-semibold text-ucla-900 sm:text-3xl"
          style="font-family: var(--font-display)"
        >
          Panel de administración
        </h1>
        <p class="mt-1 text-sm text-ucla-900/50">Resumen general de la tienda</p>
      </div>
    </div>

    <div class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div
        v-for="stat in statCards"
        :key="stat.label"
        class="rounded-xl border border-neutral-200 bg-white p-4"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex size-10 shrink-0 items-center justify-center rounded-lg"
            :class="stat.color"
          >
            <component :is="stat.icon" class="size-5" />
          </div>
          <div>
            <p class="text-xs text-neutral-500">{{ stat.label }}</p>
            <p class="text-xl font-semibold text-neutral-900">{{ stat.value }}</p>
          </div>
        </div>
      </div>
    </div>

    <div class="mt-8 grid gap-6 lg:grid-cols-2">
      <div class="rounded-xl border border-neutral-200 bg-white">
        <div class="flex items-center justify-between border-b border-neutral-100 px-5 py-4">
          <h2 class="text-sm font-semibold text-neutral-900">Órdenes recientes</h2>
          <router-link
            to="/admin/ordenes"
            class="text-xs font-medium text-ucla-600 hover:text-ucla-700"
          >
            Ver todas
          </router-link>
        </div>

        <div class="divide-y divide-neutral-50">
          <div
            v-for="order in recentOrders"
            :key="order.id"
            class="flex items-center justify-between px-5 py-3"
          >
            <div class="min-w-0">
              <p class="text-sm font-medium text-neutral-900">
                {{ order.customer_first_name }}
                {{ order.customer_last_name }}
              </p>
              <p class="text-xs text-neutral-400">{{ order.id }}</p>
            </div>

            <div class="flex items-center gap-3">
              <span
                class="rounded-full border px-2.5 py-0.5 text-[10px] font-medium capitalize"
                :class="statusColors[order.status] || ''"
              >
                {{ statusLabels[order.status] || order.status }}
              </span>
              <PriceDisplay :price="order.total" class="text-sm font-semibold text-neutral-700" />
            </div>
          </div>
        </div>
      </div>

      <div class="rounded-xl border border-neutral-200 bg-white p-5">
        <h2 class="text-sm font-semibold text-neutral-900">Acciones rápidas</h2>
        <div class="mt-4 space-y-2">
          <Button
            variant="outline"
            class="w-full justify-start"
            as="router-link"
            to="/admin/productos/nuevo"
          >
            <Plus class="size-4" />
            Nuevo producto
          </Button>
          <Button
            variant="outline"
            class="w-full justify-start"
            as="router-link"
            to="/admin/jornadas/nueva"
          >
            <Plus class="size-4" />
            Nueva jornada
          </Button>
          <Button
            variant="outline"
            class="w-full justify-start"
            as="router-link"
            to="/admin/ordenes"
          >
            <ArrowRight class="size-4" />
            Gestionar órdenes
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>
