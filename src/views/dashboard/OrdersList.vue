<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Search,
  Eye,
  FileSpreadsheet,
  Printer,
  Loader2,
  ChevronLeft,
  ChevronRight,
} from '@lucide/vue'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { statusColors, statusLabels } from '@/lib/mock'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'
import OrderDetailModal from '@/components/dashboard/OrderDetailModal.vue'
import { fetchOrderItems, exportOrdersToXlsx, printOrdersReport } from '@/lib/ordersExport'

const route = useRoute()
const router = useRouter()
const search = ref('')
const filterStatus = ref('')
const orders = ref([])

const page = ref(1)
const pageSize = ref(10)
const pageSizeOptions = [
  { value: '10', label: '10' },
  { value: '25', label: '25' },
  { value: '50', label: '50' },
]

const detailOpen = ref(false)
const selectedId = ref(null)
const selectedOrder = ref(null)
const exporting = ref('')

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
  openFromQuery()
}

onMounted(fetchOrders)

function openFromQuery() {
  const id = String(route.query.orden || '')
  if (!id) return
  selectedId.value = id
  selectedOrder.value = orders.value.find((order) => order.id === id) || null
  // Jump to the page that contains the linked order (when it is visible).
  const index = filtered.value.findIndex((order) => order.id === id)
  if (index !== -1) page.value = Math.floor(index / pageSize.value) + 1
  detailOpen.value = true
}

watch(
  () => route.query.orden,
  (id) => {
    if (!id) return
    if (detailOpen.value && selectedId.value === String(id)) return
    openFromQuery()
  }
)

function openOrder(order) {
  selectedId.value = order.id
  selectedOrder.value = order
  detailOpen.value = true
  if (route.query.orden !== order.id) {
    router.replace({ query: { ...route.query, orden: order.id } })
  }
}

watch(detailOpen, (isOpen) => {
  if (isOpen || !route.query.orden) return
  const query = { ...route.query }
  delete query.orden
  router.replace({ query })
})

function handleUpdated(updated) {
  const index = orders.value.findIndex((order) => order.id === updated.id)
  if (index !== -1) orders.value[index] = { ...orders.value[index], ...updated }
  selectedId.value = updated.id
  selectedOrder.value = { ...updated }
}

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

const totalPages = computed(() =>
  Math.max(1, Math.ceil(filtered.value.length / pageSize.value))
)

const paginated = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})

const pageRange = computed(() => {
  if (!filtered.value.length) return '0'
  const start = (page.value - 1) * pageSize.value + 1
  const end = Math.min(page.value * pageSize.value, filtered.value.length)
  return `${start}–${end}`
})

watch([search, filterStatus, pageSize], () => {
  page.value = 1
})

watch(totalPages, () => {
  if (page.value > totalPages.value) page.value = totalPages.value
})

async function runExport(kind) {
  if (exporting.value) return
  if (!filtered.value.length) {
    toast.error('No hay órdenes para exportar')
    return
  }

  exporting.value = kind
  try {
    const itemsByOrder = await fetchOrderItems(filtered.value)

    if (kind === 'xlsx') {
      await exportOrdersToXlsx(filtered.value, itemsByOrder)
      toast.success('Excel generado correctamente')
    } else {
      const filterLabel =
        filterStatus.value &&
        statusFilters.find((filter) => filter.value === filterStatus.value)?.label
      const meta = [filterLabel ? `Filtro: ${filterLabel}` : 'Todas las órdenes']
      const query = search.value.trim()
      if (query) meta.push(`Búsqueda: "${query}"`)
      printOrdersReport(filtered.value, itemsByOrder, { filters: meta.join(' · ') })
    }
  } catch (error) {
    console.error('runExport', error)
    toast.error(
      error?.message === 'popup_blocked'
        ? 'Permite las ventanas emergentes para generar el PDF'
        : 'No se pudo generar el archivo'
    )
  } finally {
    exporting.value = ''
  }
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Órdenes
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          <template v-if="filtered.length">
            {{ pageRange }} de {{ filtered.length }}
            {{ filtered.length === 1 ? 'orden' : 'órdenes' }}
          </template>
          <template v-else>0 órdenes</template>
        </p>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <div class="relative">
          <Search
            class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400"
          />
          <Input
            v-model="search"
            type="search"
            placeholder="Buscar orden..."
            class="w-44 pl-9 sm:w-56"
          />
        </div>

        <Button
          variant="outline"
          size="sm"
          :disabled="!!exporting || !filtered.length"
          title="Exportar todas las órdenes filtradas"
          @click="runExport('xlsx')"
        >
          <Loader2 v-if="exporting === 'xlsx'" class="size-4 animate-spin" />
          <FileSpreadsheet v-else class="size-4" />
          Excel
        </Button>

        <Button
          variant="outline"
          size="sm"
          :disabled="!!exporting || !filtered.length"
          title="Imprimir todas las órdenes filtradas"
          @click="runExport('pdf')"
        >
          <Loader2 v-if="exporting === 'pdf'" class="size-4 animate-spin" />
          <Printer v-else class="size-4" />
          PDF
        </Button>
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

    <div class="mt-4 hidden overflow-hidden rounded-xl border border-neutral-200 bg-white lg:block">
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
            v-for="order in paginated"
            :key="order.id"
            class="cursor-pointer transition-colors hover:bg-neutral-50/50"
            @click="openOrder(order)"
          >
            <td class="px-4 py-3 font-mono text-xs text-neutral-700">{{ order.id }}</td>
            <td class="px-4 py-3">
              <p class="font-medium text-neutral-900">
                {{ order.customer_first_name }} {{ order.customer_last_name }}
              </p>
              <p class="text-xs text-neutral-400">{{ order.customer_phone }}</p>
            </td>
            <td class="px-4 py-3 font-semibold text-neutral-700 tabular-nums">
              <PriceDisplay :price="Number(order.total)" />
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
                aria-label="Ver detalle"
                @click.stop="openOrder(order)"
              >
                <Eye class="size-4" />
              </button>
            </td>
          </tr>
          <tr v-if="!filtered.length">
            <td colspan="6" class="px-4 py-12 text-center text-sm text-neutral-400">
              No hay órdenes que coincidan con el filtro.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="mt-4 space-y-3 lg:hidden">
      <div
        v-for="order in paginated"
        :key="order.id"
        class="rounded-xl border border-neutral-200 bg-white p-4"
        @click="openOrder(order)"
      >
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="break-all font-mono text-xs text-neutral-700">{{ order.id }}</p>
            <p class="mt-1 font-medium text-neutral-900">
              {{ order.customer_first_name }} {{ order.customer_last_name }}
            </p>
            <p class="text-xs text-neutral-400">{{ order.customer_phone }}</p>
          </div>
          <span
            class="shrink-0 rounded-full border px-2.5 py-0.5 text-[10px] font-medium capitalize"
            :class="statusColors[order.status] || ''"
          >
            {{ statusLabels[order.status] || order.status }}
          </span>
        </div>

        <div class="mt-3 flex items-center justify-between gap-3">
          <div>
            <p class="text-xs text-neutral-500">
              {{ new Date(order.created_at).toLocaleDateString('es-ES') }}
            </p>
            <p class="mt-0.5 text-sm font-semibold text-neutral-700 tabular-nums">
              <PriceDisplay :price="Number(order.total)" />
            </p>
          </div>
          <Button size="sm" variant="outline" @click.stop="openOrder(order)">
            <Eye class="size-3.5" />
            Ver detalle
          </Button>
        </div>
      </div>

      <div
        v-if="!filtered.length"
        class="rounded-xl border border-dashed border-neutral-200 bg-white px-4 py-10 text-center text-sm text-neutral-400"
      >
        No hay órdenes que coincidan con el filtro.
      </div>
    </div>

    <div
      v-if="filtered.length"
      class="mt-4 flex flex-col items-center justify-between gap-3 sm:flex-row"
    >
      <div class="flex items-center gap-2 text-sm text-neutral-500">
        <span>Filas por página</span>
        <Select
          :model-value="String(pageSize)"
          @update:model-value="pageSize = Number($event)"
        >
          <SelectTrigger size="sm" class="w-20">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem v-for="opt in pageSizeOptions" :key="opt.value" :value="opt.value">
              {{ opt.label }}
            </SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div class="flex items-center gap-1">
        <Button
          size="sm"
          variant="outline"
          :disabled="page <= 1"
          aria-label="Página anterior"
          @click="page--"
        >
          <ChevronLeft class="size-4" />
        </Button>
        <span class="px-2 text-sm tabular-nums text-neutral-600">{{ page }} / {{ totalPages }}</span>
        <Button
          size="sm"
          variant="outline"
          :disabled="page >= totalPages"
          aria-label="Página siguiente"
          @click="page++"
        >
          <ChevronRight class="size-4" />
        </Button>
      </div>
    </div>

    <OrderDetailModal
      v-model:open="detailOpen"
      :order-id="selectedId"
      :initial-order="selectedOrder"
      @updated="handleUpdated"
    />
  </div>
</template>
