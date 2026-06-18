<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search, Eye } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { statusColors, statusLabels } from '@/lib/mock'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'

const router = useRouter()
const search = ref('')
const filterStatus = ref('')
const orders = ref([])

const statusFilters = [
  { value: '', label: 'Todas' },
  { value: 'pending_payment', label: 'Pendientes' },
  { value: 'paid', label: 'Pagadas' },
  { value: 'in_delivery', label: 'En entrega' },
  { value: 'delivered', label: 'Entregadas' },
  { value: 'rejected', label: 'Rechazadas' },
]

async function fetchOrders() {
  const { data, error } = await supabase
    .from('orders')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) {
    console.error('fetchOrders', error)
    orders.value = []
    toast.error('Error cargando órdenes')
    return
  }
  orders.value = data || []
}

onMounted(fetchOrders)

const filtered = computed(() => {
  let result = [...orders.value]
  if (filterStatus.value) result = result.filter((o) => o.status === filterStatus.value)
  const q = search.value.trim().toLowerCase()
  if (q) {
    result = result.filter(
      (o) =>
        String(o.id).toLowerCase().includes(q) ||
        String(o.customer_first_name || '')
          .toLowerCase()
          .includes(q) ||
        String(o.customer_last_name || '')
          .toLowerCase()
          .includes(q) ||
        String(o.customer_phone || '').includes(q)
    )
  }
  return result
})
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Órdenes
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtered.length }} {{ filtered.length === 1 ? 'orden' : 'órdenes' }}
        </p>
      </div>

      <div class="relative">
        <Search
          class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400"
        />
        <Input
          v-model="search"
          type="search"
          placeholder="Buscar orden..."
          class="w-48 pl-9 sm:w-64"
        />
      </div>
    </div>

    <div class="mt-4 flex flex-wrap gap-2">
      <button
        v-for="f in statusFilters"
        :key="f.value"
        class="rounded-full border px-3 py-1 text-xs font-medium transition-colors"
        :class="
          filterStatus === f.value
            ? 'border-ucla-600 bg-ucla-50 text-ucla-600'
            : 'border-neutral-200 text-neutral-500 hover:border-neutral-300'
        "
        @click="filterStatus = f.value"
      >
        {{ f.label }}
      </button>
    </div>

    <div class="mt-4 overflow-hidden rounded-xl border border-neutral-200 bg-white">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-neutral-100 bg-neutral-50/50">
          <tr>
            <th class="px-4 py-3 font-medium text-neutral-500">Nro</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Cliente</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Total</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Estado</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Fecha</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-neutral-50">
          <tr
            v-for="order in filtered"
            :key="order.id"
            class="transition-colors hover:bg-neutral-50/50"
          >
            <td class="px-4 py-3 font-mono text-xs text-neutral-700">{{ order.id }}</td>
            <td class="px-4 py-3">
              <p class="font-medium text-neutral-900">
                {{ order.customer_first_name }} {{ order.customer_last_name }}
              </p>
              <p class="text-xs text-neutral-400">{{ order.customer_phone }}</p>
            </td>
            <td class="px-4 py-3 font-semibold text-neutral-700 tabular-nums">
              <PriceDisplay :price="order.total" />
            </td>
            <td class="px-4 py-3">
              <span
                class="rounded-full border px-2.5 py-0.5 text-[10px] font-medium capitalize"
                :class="statusColors[order.status] || ''"
              >
                {{ statusLabels[order.status] || order.status }}
              </span>
            </td>
            <td class="px-4 py-3 text-xs text-neutral-500">
              {{ new Date(order.created_at).toLocaleDateString('es-ES') }}
            </td>
            <td class="px-4 py-3">
              <button
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                @click="router.push(`/admin/ordenes/${order.id}`)"
                aria-label="Ver detalle"
              >
                <Eye class="size-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
