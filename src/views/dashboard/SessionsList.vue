<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Plus, Pencil, Search } from '@lucide/vue'
import { statusColors, statusLabels } from '@/lib/mock'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import {
  Dialog,
  DialogScrollContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'

const sessions = ref([])
const products = ref([])
const search = ref('')
const dialogOpen = ref(false)
const saving = ref(false)
const editingSession = ref(null)

const form = ref({
  name: '',
  start_date: '',
  end_date: '',
  is_open: true,
  product_ids: [],
})

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return sessions.value
  return sessions.value.filter((s) => s.name.toLowerCase().includes(q))
})

const productSearch = ref('')

const filteredProducts = computed(() => {
  const q = productSearch.value.trim().toLowerCase()
  if (!q) return products.value
  return products.value.filter((p) => (p.name || '').toLowerCase().includes(q))
})

async function fetchSessions() {
  const { data, error } = await supabase
    .from('sales_sessions')
    .select('*')
    .order('start_date', { ascending: false })
  if (error) {
    console.error('fetchSessions', error)
    toast.error('Error cargando jornadas')
    sessions.value = []
  } else sessions.value = data || []

  // fetch product counts per session
  if (sessions.value.length > 0) {
    const sids = sessions.value.map((s) => s.id)
    const { data: ps, error: psErr } = await supabase
      .from('product_sessions')
      .select('session_id')
      .in('session_id', sids)
    if (!psErr && ps) {
      const countMap = {}
      ps.forEach((p) => {
        countMap[p.session_id] = (countMap[p.session_id] || 0) + 1
      })
      sessions.value.forEach((s) => {
        s.product_count = countMap[s.id] || 0
      })
    }
  }

  // ensure product_count exists even if query fails
  sessions.value.forEach((s) => {
    if (s.product_count === undefined) s.product_count = 0
  })
}

onMounted(fetchSessions)

async function openNewDialog() {
  const { data: prods, error: pErr } = await supabase
    .from('products')
    .select('id, name, price')
    .order('name')
  if (pErr) {
    console.error('loadProducts', pErr)
    toast.error('No se pudieron cargar productos')
    return
  }
  products.value = prods || []

  editingSession.value = null
  form.value = { name: '', start_date: '', end_date: '', is_open: true, product_ids: [] }
  dialogOpen.value = true
}

async function openEditDialog(session) {
  const { data: prods, error: pErr } = await supabase
    .from('products')
    .select('id, name, price')
    .order('name')
  if (pErr) {
    console.error('loadProducts', pErr)
    toast.error('No se pudieron cargar productos')
  } else products.value = prods || []

  editingSession.value = session
  form.value = {
    name: session.name || '',
    start_date: session.start_date?.slice(0, 10) || '',
    end_date: session.end_date?.slice(0, 10) || '',
    is_open: session.is_open ?? true,
    product_ids: [],
  }

  // load product_sessions for this session
  const { data: ps, error: psErr } = await supabase
    .from('product_sessions')
    .select('product_id')
    .eq('session_id', session.id)
  if (psErr) {
    console.error('loadProductSessions', psErr)
  } else form.value.product_ids = (ps || []).map((x) => x.product_id)

  dialogOpen.value = true
}

function toggleProduct(id) {
  const idx = form.value.product_ids.indexOf(id)
  if (idx >= 0) form.value.product_ids.splice(idx, 1)
  else form.value.product_ids.push(id)
}

async function handleSave() {
  if (!form.value.name.trim()) {
    toast.error('El nombre es requerido')
    return
  }
  saving.value = true
  try {
    if (editingSession.value) {
      const { error } = await supabase
        .from('sales_sessions')
        .update({
          name: form.value.name,
          start_date: form.value.start_date,
          end_date: form.value.end_date,
          is_open: form.value.is_open,
        })
        .eq('id', editingSession.value.id)
      if (error) {
        toast.error('Error actualizando jornada')
        console.error(error)
        return
      }
      // replace product_sessions
      const sid = editingSession.value.id
      await supabase.from('product_sessions').delete().eq('session_id', sid)
      for (const pid of form.value.product_ids) {
        await supabase.from('product_sessions').insert([{ product_id: pid, session_id: sid }])
      }
      toast.success('Jornada actualizada')
    } else {
      const { data: insData, error } = await supabase
        .from('sales_sessions')
        .insert([
          {
            name: form.value.name,
            start_date: form.value.start_date,
            end_date: form.value.end_date,
            is_open: form.value.is_open,
          },
        ])
        .select('id')
      if (error) {
        toast.error('Error creando jornada')
        console.error(error)
        return
      }
      const sid = (insData && insData[0] && insData[0].id) || null
      if (sid) {
        for (const pid of form.value.product_ids) {
          await supabase.from('product_sessions').insert([{ product_id: pid, session_id: sid }])
        }
      }
      toast.success('Jornada creada')
    }
    dialogOpen.value = false
    await fetchSessions()
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Jornadas
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtered.length }} {{ filtered.length === 1 ? 'jornada' : 'jornadas' }}
        </p>
      </div>

      <div class="flex items-center gap-3">
        <div class="relative">
          <Search
            class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400"
          />
          <Input v-model="search" type="search" placeholder="Buscar..." class="w-48 pl-9 sm:w-56" />
        </div>
        <Button @click="openNewDialog">
          <Plus class="size-4" />
          Nueva
        </Button>
      </div>
    </div>

    <div class="mt-6 overflow-hidden rounded-xl border border-neutral-200 bg-white">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-neutral-100 bg-neutral-50/50">
          <tr>
            <th class="px-4 py-3 font-medium text-neutral-500">Nombre</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Inicio</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Fin</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Estado</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Productos</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-neutral-50">
          <tr
            v-for="session in filtered"
            :key="session.id"
            class="transition-colors hover:bg-neutral-50/50"
          >
            <td class="px-4 py-3 font-medium text-neutral-900">{{ session.name }}</td>
            <td class="px-4 py-3 text-neutral-600">
              {{ new Date(session.start_date).toLocaleDateString('es-ES') }}
            </td>
            <td class="px-4 py-3 text-neutral-600">
              {{ new Date(session.end_date).toLocaleDateString('es-ES') }}
            </td>
            <td class="px-4 py-3">
              <span
                class="rounded-full border px-2.5 py-0.5 text-[10px] font-medium"
                :class="session.is_open ? statusColors.paid : statusColors.rejected"
              >
                {{ session.is_open ? 'Abierta' : 'Cerrada' }}
              </span>
            </td>
            <td class="px-4 py-3 text-neutral-600">{{ session.product_count ?? '-' }}</td>
            <td class="px-4 py-3">
              <button
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                @click="openEditDialog(session)"
                aria-label="Editar"
              >
                <Pencil class="size-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <Dialog v-model:open="dialogOpen">
    <DialogScrollContent class="sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>{{ editingSession ? 'Editar jornada' : 'Nueva jornada' }}</DialogTitle>
        <DialogDescription>
          {{
            editingSession
              ? 'Modificá los datos de la jornada.'
              : 'Completá los datos de la nueva jornada.'
          }}
        </DialogDescription>
      </DialogHeader>

      <form id="session-form" @submit.prevent="handleSave" class="space-y-4">
        <div class="grid gap-2">
          <Label for="sess-name">Nombre *</Label>
          <Input id="sess-name" v-model="form.name" placeholder="Ej: Jornada de julio" required />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="grid gap-2">
            <Label for="sess-start">Fecha inicio *</Label>
            <Input id="sess-start" v-model="form.start_date" type="date" required />
          </div>
          <div class="grid gap-2">
            <Label for="sess-end">Fecha fin *</Label>
            <Input id="sess-end" v-model="form.end_date" type="date" required />
          </div>
        </div>

        <label class="flex items-center gap-2 text-sm">
          <input
            v-model="form.is_open"
            type="checkbox"
            class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
          />
          Jornada abierta
        </label>

        <div>
          <p class="mb-2 text-sm font-medium text-neutral-700">Productos disponibles</p>
          <div class="rounded-lg border border-neutral-200">
            <div class="relative border-b border-neutral-200">
              <Search class="pointer-events-none absolute left-2.5 top-1/2 size-3.5 -translate-y-1/2 text-neutral-400" />
              <Input
                v-model="productSearch"
                type="search"
                placeholder="Buscar productos..."
                class="border-0 pl-8 text-sm shadow-none"
              />
            </div>
            <div class="max-h-48 space-y-1.5 overflow-y-auto p-2">
              <label
                v-for="product in filteredProducts"
                :key="product.id"
                class="flex cursor-pointer items-center gap-3 rounded-md px-2 py-1.5 text-sm transition-colors hover:bg-neutral-50"
                :class="{ 'bg-ucla-50': form.product_ids.includes(product.id) }"
              >
                <input
                  type="checkbox"
                  :checked="form.product_ids.includes(product.id)"
                  class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
                  @change="toggleProduct(product.id)"
                />
                <span class="flex-1">{{ product.name }}</span>
                <PriceDisplay :price="product.price" class="text-xs text-neutral-400" />
              </label>
              <p v-if="filteredProducts.length === 0" class="py-4 text-center text-xs text-neutral-400">
                No se encontraron productos
              </p>
            </div>
          </div>
        </div>
      </form>

      <DialogFooter>
        <Button type="submit" form="session-form" :disabled="saving">
          {{ saving ? 'Guardando...' : editingSession ? 'Guardar cambios' : 'Crear jornada' }}
        </Button>
      </DialogFooter>
    </DialogScrollContent>
  </Dialog>
</template>
