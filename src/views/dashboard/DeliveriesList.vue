<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { statusLabels, statusColors } from '@/lib/mock'

const search = ref('')
const filterStatus = ref('')
const deliveries = ref([])
const ordersMap = ref({})

const filtered = computed(() => {
  let result = [...deliveries.value]
  if (filterStatus.value) {
    result = result.filter((d) => d.status === filterStatus.value)
  }
  const q = search.value.trim().toLowerCase()
  if (q) {
    result = result.filter((d) => String(d.order_id).toLowerCase().includes(q))
  }
  return result
})

function findOrder(id) {
  return ordersMap.value[id] || null
}

async function fetchData() {
  const { data: d, error } = await supabase
    .from('deliveries')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) {
    console.error('fetchDeliveries', error)
    toast.error('No se pudieron cargar las entregas')
    deliveries.value = []
  } else deliveries.value = d || []

  // preload orders minimal info
  const { data: o, error: oErr } = await supabase
    .from('orders')
    .select('id, customer_first_name, customer_last_name')
  if (oErr) {
    console.error('fetchOrdersForDeliveries', oErr)
  } else {
    const map = {}(o || []).forEach((x) => (map[x.id] = x))
    ordersMap.value = map
  }
}

onMounted(fetchData)
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Entregas
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtered.length }} {{ filtered.length === 1 ? 'entrega' : 'entregas' }}
        </p>
      </div>

      <div class="relative">
        <Search
          class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400"
        />
        <Input
          v-model="search"
          type="search"
          placeholder="Buscar por orden..."
          class="w-48 pl-9 sm:w-64"
        />
      </div>
    </div>

    <div class="mt-4 flex gap-2">
      <button
        v-for="f in [
          { value: '', label: 'Todas' },
          { value: 'preparing', label: 'Preparando' },
          { value: 'out_for_delivery', label: 'En camino' },
          { value: 'delivered', label: 'Entregadas' },
        ]"
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
            <th class="px-4 py-3 font-medium text-neutral-500">Orden</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Cliente</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Estado</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Notas</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Fecha</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-neutral-50">
          <tr v-for="d in filtered" :key="d.id" class="transition-colors hover:bg-neutral-50/50">
            <td class="px-4 py-3 font-mono text-xs text-neutral-700">{{ d.order_id }}</td>
            <td class="px-4 py-3 text-neutral-900">
              {{ findOrder(d.order_id)?.customer_first_name }}
              {{ findOrder(d.order_id)?.customer_last_name }}
            </td>
            <td class="px-4 py-3">
              <span
                class="rounded-full border px-2.5 py-0.5 text-[10px] font-medium"
                :class="statusColors[d.status] || ''"
              >
                {{ statusLabels[d.status] || d.status }}
              </span>
            </td>
            <td class="max-w-[200px] truncate px-4 py-3 text-xs text-neutral-500">
              {{ d.notes || '—' }}
            </td>
            <td class="px-4 py-3 text-xs text-neutral-500">
              {{ new Date(d.created_at).toLocaleDateString('es-ES') }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
