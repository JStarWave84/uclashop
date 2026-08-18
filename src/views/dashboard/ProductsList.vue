<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import {
  Plus,
  Search,
  Pencil,
  EyeOff,
  Eye,
  Trash2,
  ImageUp,
  ExternalLink,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  ChevronUp,
  ChevronDown,
  X,
} from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import {
  Dialog,
  DialogScrollContent,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'
import { validateProduct } from '@/schemas/product'

const LOW_STOCK = 5

const route = useRoute()
const search = ref('')
const products = ref([])
const dialogOpen = ref(false)
const saving = ref(false)
const editingProduct = ref(null)
const formErrors = ref({})

const form = ref({
  name: '',
  description: '',
  price: '',
  stock: 0,
  allow_backorder: false,
  is_active: true,
  contact_phone: '',
  payment_account_ids: [],
})

const imageInput = ref(null)
const imageFile = ref(null)
const imagePreview = ref(null)
const dragOver = ref(false)
const paymentAccounts = ref([])

// Filters, sorting & pagination
const statusFilter = ref('all')
const stockFilter = ref('all')
const sortKey = ref('created_at')
const sortDir = ref('desc')
const page = ref(1)
const pageSize = ref(10)

// Bulk selection
const selected = ref(new Set())
const deleteDialogOpen = ref(false)
const deleteTarget = ref(null)
const deleteBulkCount = ref(0)

function productImageUrl(path) {
  if (!path) return null
  const {
    data: { publicUrl },
  } = supabase.storage.from('product-images').getPublicUrl(path)
  return publicUrl
}

async function fetchProducts() {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) {
    console.error('fetchProducts', error)
    products.value = []
    toast.error('Error cargando productos')
    return
  }
  const result = (data || []).map((p) => ({ ...p, jornadas: [] }))

  const { data: ps, error: psErr } = await supabase
    .from('product_sessions')
    .select('product_id, session_id, sales_sessions(name)')
  if (psErr) {
    console.error('fetchProductSessions', psErr)
  } else {
    const jornadasMap = {}
    for (const row of ps || []) {
      const name = row.sales_sessions?.name
      if (!name) continue
      if (!jornadasMap[row.product_id]) jornadasMap[row.product_id] = []
      jornadasMap[row.product_id].push(name)
    }
    result.forEach((p) => {
      p.jornadas = jornadasMap[p.id] || []
    })
  }

  products.value = result
}

onMounted(async () => {
  await fetchProducts()
  await fetchPaymentAccounts()
  if (route.query.nuevo === '1') openNewDialog()
})

async function fetchPaymentAccounts() {
  const { data } = await supabase
    .from('payment_accounts')
    .select('*')
    .eq('is_active', true)
    .order('name')
  if (data) paymentAccounts.value = data
}

function togglePaymentAccount(id) {
  const idx = form.value.payment_account_ids.indexOf(id)
  if (idx >= 0) form.value.payment_account_ids.splice(idx, 1)
  else form.value.payment_account_ids.push(id)
}

const filteredProducts = computed(() => {
  const q = search.value.trim().toLowerCase()
  return products.value.filter((p) => {
    if (q) {
      const haystack = `${p.name || ''} ${p.description || ''}`.toLowerCase()
      if (!haystack.includes(q)) return false
    }
    if (statusFilter.value === 'active' && p.is_active === false) return false
    if (statusFilter.value === 'inactive' && p.is_active !== false) return false
    if (stockFilter.value === 'in_stock' && !(p.stock > 0)) return false
    if (stockFilter.value === 'low' && !(p.stock > 0 && p.stock <= LOW_STOCK)) return false
    if (stockFilter.value === 'out' && !(p.stock === 0 && !p.allow_backorder)) return false
    if (stockFilter.value === 'backorder' && !p.allow_backorder) return false
    return true
  })
})

const sortedProducts = computed(() => {
  const arr = [...filteredProducts.value]
  const dir = sortDir.value === 'asc' ? 1 : -1
  switch (sortKey.value) {
    case 'name':
      arr.sort((a, b) => (a.name || '').localeCompare(b.name || '') * dir)
      break
    case 'price':
      arr.sort((a, b) => ((a.price || 0) - (b.price || 0)) * dir)
      break
    case 'stock':
      arr.sort((a, b) => ((a.stock || 0) - (b.stock || 0)) * dir)
      break
    case 'estado':
      arr.sort((a, b) => ((b.is_active ? 1 : 0) - (a.is_active ? 1 : 0)) * dir)
      break
    default:
      arr.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
  }
  return arr
})

const totalPages = computed(() =>
  Math.max(1, Math.ceil(sortedProducts.value.length / pageSize.value))
)

const paginated = computed(() => {
  const start = (page.value - 1) * pageSize.value
  return sortedProducts.value.slice(start, start + pageSize.value)
})

const pageRange = computed(() => {
  if (sortedProducts.value.length === 0) return '0–0'
  const start = (page.value - 1) * pageSize.value + 1
  const end = Math.min(page.value * pageSize.value, sortedProducts.value.length)
  return `${start}–${end}`
})

watch([search, statusFilter, stockFilter, pageSize], () => {
  page.value = 1
})

watch(totalPages, () => {
  if (page.value > totalPages.value) page.value = totalPages.value
})

function setSort(key) {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = key
    sortDir.value = key === 'name' ? 'asc' : 'desc'
  }
}

function stockMeta(p) {
  if (p.stock === 0 && p.allow_backorder)
    return { badge: 'Backorder', badgeCls: 'bg-ucla-gold/10 text-ucla-gold', numCls: 'text-ucla-gold' }
  if (p.stock === 0)
    return { badge: 'Agotado', badgeCls: 'bg-red-50 text-red-600', numCls: 'text-red-600' }
  if (p.stock <= LOW_STOCK)
    return { badge: 'Bajo', badgeCls: 'bg-amber-50 text-amber-600', numCls: 'text-amber-600' }
  return { badge: null, badgeCls: '', numCls: 'text-neutral-700' }
}

async function toggleActive(id) {
  const p = products.value.find((p) => p.id === id)
  if (!p) return
  const { error } = await supabase.from('products').update({ is_active: !p.is_active }).eq('id', id)
  if (error) {
    console.error('toggleActive', error)
    toast.error('No se pudo actualizar el estado del producto')
  } else {
    p.is_active = !p.is_active
    toast.success('Estado del producto actualizado')
  }
}

function resetForm() {
  form.value = {
    name: '',
    description: '',
    price: '',
    stock: 0,
    allow_backorder: false,
    is_active: true,
    contact_phone: '',
    payment_account_ids: [],
  }
  formErrors.value = {}
  imageFile.value = null
  imagePreview.value = null
}

function openNewDialog() {
  editingProduct.value = null
  resetForm()
  dialogOpen.value = true
}

async function openEditDialog(product) {
  editingProduct.value = product

  const { data: ppa } = await supabase
    .from('product_payment_accounts')
    .select('payment_account_id')
    .eq('product_id', product.id)
  const linkedIds = (ppa || []).map((r) => r.payment_account_id)

  form.value = {
    name: product.name || '',
    description: product.description || '',
    price: product.price ?? '',
    stock: product.stock ?? 0,
    allow_backorder: product.allow_backorder ?? false,
    is_active: product.is_active ?? true,
    contact_phone: product.contact_phone || '',
    payment_account_ids: linkedIds,
  }
  formErrors.value = {}
  imageFile.value = null
  imagePreview.value = product.product_image_path ? productImageUrl(product.product_image_path) : null
  dialogOpen.value = true
}

function selectImage(file) {
  if (!file) return
  if (!file.type.startsWith('image/')) {
    toast.error('Solo se permiten imágenes')
    return
  }
  imageFile.value = file
  imagePreview.value = URL.createObjectURL(file)
}

function onImageSelected(e) {
  selectImage(e.target.files?.[0])
  e.target.value = ''
}

function onDrop(e) {
  dragOver.value = false
  selectImage(e.dataTransfer?.files?.[0])
}

function removeImage() {
  imageFile.value = null
  imagePreview.value = null
}

async function uploadImage(productId) {
  if (!imageFile.value) return null
  const ext = imageFile.value.name.split('.').pop()
  const path = `${productId}/${Date.now()}.${ext}`
  const { error } = await supabase.storage
    .from('product-images')
    .upload(path, imageFile.value, { upsert: true })
  if (error) {
    console.error('uploadImage', error)
    throw error
  }
  return path
}

async function syncPaymentAccounts(productId) {
  const { error: delErr } = await supabase
    .from('product_payment_accounts')
    .delete()
    .eq('product_id', productId)
  if (delErr) {
    console.error('syncPaymentAccounts delete', delErr)
    toast.error('No se pudieron actualizar las cuentas de pago')
    return false
  }
  if (form.value.payment_account_ids.length > 0) {
    const inserts = form.value.payment_account_ids.map((paid, i) => ({
      product_id: productId,
      payment_account_id: paid,
      is_primary: i === 0,
    }))
    const { error } = await supabase.from('product_payment_accounts').insert(inserts)
    if (error) {
      console.error('syncPaymentAccounts insert', error)
      toast.error('No se pudieron actualizar las cuentas de pago')
      return false
    }
  }
  return true
}

async function handleSave() {
  const { valid, errors, data } = validateProduct(form.value)
  if (!valid) {
    formErrors.value = errors
    toast.error('Revisá los campos marcados')
    return
  }
  formErrors.value = {}

  saving.value = true
  try {
    const payload = {
      name: data.name,
      description: data.description,
      price: data.price,
      stock: data.stock,
      allow_backorder: data.allow_backorder,
      is_active: data.is_active,
      contact_phone: data.contact_phone || null,
    }

    if (editingProduct.value) {
      const updates = { ...payload }
      const oldPath = editingProduct.value.product_image_path
      if (imageFile.value) {
        const path = await uploadImage(editingProduct.value.id)
        updates.product_image_path = path
        if (oldPath && oldPath !== path) {
          await supabase.storage.from('product-images').remove([oldPath]).catch(() => {})
        }
      } else if (imagePreview.value === null && oldPath) {
        await supabase.storage.from('product-images').remove([oldPath]).catch(() => {})
        updates.product_image_path = null
      }
      const { error } = await supabase
        .from('products')
        .update(updates)
        .eq('id', editingProduct.value.id)
      if (error) {
        toast.error('Error actualizando producto')
        console.error(error)
        return
      }
      toast.success('Producto actualizado')
      await syncPaymentAccounts(editingProduct.value.id)
    } else {
      const { data: inserted, error } = await supabase
        .from('products')
        .insert([payload])
        .select('id')
        .single()
      if (error) {
        toast.error('Error creando producto')
        console.error(error)
        return
      }
      if (imageFile.value) {
        const path = await uploadImage(inserted.id)
        await supabase.from('products').update({ product_image_path: path }).eq('id', inserted.id)
      }
      await syncPaymentAccounts(inserted.id)
      toast.success('Producto creado')
    }
    dialogOpen.value = false
    await fetchProducts()
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    saving.value = false
  }
}

// ── Bulk selection ──
const allPageSelected = computed(() =>
  paginated.value.length > 0 && paginated.value.every((p) => selected.value.has(p.id))
)

function toggleSelect(id) {
  const s = new Set(selected.value)
  if (s.has(id)) s.delete(id)
  else s.add(id)
  selected.value = s
}

function toggleSelectAll() {
  const ids = paginated.value.map((p) => p.id)
  const s = new Set(selected.value)
  if (ids.every((id) => s.has(id))) ids.forEach((id) => s.delete(id))
  else ids.forEach((id) => s.add(id))
  selected.value = s
}

function clearSelection() {
  selected.value = new Set()
}

async function bulkSetActive(active) {
  const ids = [...selected.value]
  if (ids.length === 0) return
  const { error } = await supabase.from('products').update({ is_active: active }).in('id', ids)
  if (error) {
    console.error('bulkSetActive', error)
    toast.error('No se pudo actualizar el estado')
    return
  }
  toast.success(active ? 'Productos activados' : 'Productos desactivados')
  clearSelection()
  await fetchProducts()
}

function openBulkDelete() {
  deleteBulkCount.value = selected.value.size
  deleteTarget.value = null
  deleteDialogOpen.value = true
}

function openDeleteDialog(product) {
  deleteTarget.value = product
  deleteBulkCount.value = 0
  deleteDialogOpen.value = true
}

async function confirmDelete() {
  if (deleteTarget.value) {
    saving.value = true
    try {
      if (deleteTarget.value.product_image_path) {
        await supabase.storage
          .from('product-images')
          .remove([deleteTarget.value.product_image_path])
          .catch(() => {})
      }
      const { error } = await supabase
        .from('products')
        .delete()
        .eq('id', deleteTarget.value.id)
      if (error) {
        toast.error('Error eliminando producto')
        console.error(error)
        return
      }
      toast.success('Producto eliminado')
    } catch (e) {
      console.error(e)
      toast.error('Error inesperado')
      return
    } finally {
      saving.value = false
    }
  } else if (deleteBulkCount.value > 0) {
    saving.value = true
    try {
      const ids = [...selected.value]
      const targets = products.value.filter((p) => ids.includes(p.id))
      const paths = targets.map((p) => p.product_image_path).filter(Boolean)
      if (paths.length > 0) {
        await supabase.storage.from('product-images').remove(paths).catch(() => {})
      }
      const { error } = await supabase.from('products').delete().in('id', ids)
      if (error) {
        toast.error('Error eliminando productos')
        console.error(error)
        return
      }
      toast.success(`${ids.length} producto(s) eliminados`)
    } catch (e) {
      console.error(e)
      toast.error('Error inesperado')
      return
    } finally {
      saving.value = false
    }
  }
  deleteDialogOpen.value = false
  deleteTarget.value = null
  deleteBulkCount.value = 0
  clearSelection()
  await fetchProducts()
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Productos
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filteredProducts.length }}
          {{ filteredProducts.length === 1 ? 'producto' : 'productos' }}
        </p>
      </div>

      <div class="flex items-center gap-3">
        <div class="relative">
          <Search
            class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400"
          />
          <Input
            v-model="search"
            type="search"
            placeholder="Buscar productos..."
            class="w-48 pl-9 sm:w-56"
          />
        </div>
        <Button @click="openNewDialog">
          <Plus class="size-4" />
          Nuevo
        </Button>
      </div>
    </div>

    <div class="mt-6 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
      <div class="flex flex-wrap items-center gap-2">
        <div class="flex rounded-lg border border-neutral-200 bg-neutral-50 p-0.5">
          <button
            v-for="opt in [
              { value: 'all', label: 'Todos' },
              { value: 'active', label: 'Activos' },
              { value: 'inactive', label: 'Inactivos' },
            ]"
            :key="opt.value"
            class="rounded-md px-3 py-1 text-xs font-medium transition-colors"
            :class="
              statusFilter === opt.value
                ? 'bg-white text-ucla-700 shadow-sm'
                : 'text-neutral-500 hover:text-neutral-800'
            "
            @click="statusFilter = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
        <select
          v-model="stockFilter"
          class="h-9 rounded-md border border-neutral-200 bg-white px-2 text-sm text-neutral-700 outline-none focus:border-ucla-400"
        >
          <option value="all">Todo el stock</option>
          <option value="in_stock">Con stock</option>
          <option value="low">Stock bajo (≤ {{ LOW_STOCK }})</option>
          <option value="out">Agotados</option>
          <option value="backorder">Backorder</option>
        </select>
      </div>

      <p v-if="sortedProducts.length > 0" class="text-sm text-neutral-500">
        Mostrando {{ pageRange }} de {{ sortedProducts.length }}
      </p>
    </div>

    <div
      v-if="selected.size > 0"
      class="mt-3 flex flex-col gap-2 rounded-lg border border-ucla-200 bg-ucla-50 px-3 py-2 sm:flex-row sm:items-center sm:justify-between"
    >
      <span class="text-sm font-medium text-ucla-700">
        {{ selected.size }} {{ selected.size === 1 ? 'producto' : 'productos' }} seleccionados
      </span>
      <div class="flex flex-wrap items-center gap-2">
        <Button size="sm" variant="outline" @click="bulkSetActive(true)">Activar</Button>
        <Button size="sm" variant="outline" @click="bulkSetActive(false)">Desactivar</Button>
        <Button
          size="sm"
          variant="outline"
          class="text-red-500 hover:text-red-600"
          @click="openBulkDelete"
        >
          <Trash2 class="size-3.5" />
          Eliminar
        </Button>
        <button
          class="rounded-md p-1 text-ucla-400 transition-colors hover:text-ucla-700"
          @click="clearSelection"
          aria-label="Limpiar selección"
        >
          <X class="size-4" />
        </button>
      </div>
    </div>

    <div v-if="paginated.length === 0" class="mt-6 py-12 text-center">
      <Search class="mx-auto size-8 text-neutral-300" />
      <p class="mt-3 text-sm text-neutral-500">No hay productos que coincidan</p>
    </div>
    <div v-else class="mt-6 hidden overflow-hidden rounded-xl border border-neutral-200 bg-white lg:block">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-neutral-100 bg-neutral-50/50">
          <tr>
            <th class="w-10 px-4 py-3">
              <input
                type="checkbox"
                :checked="allPageSelected"
                class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
                aria-label="Seleccionar página"
                @change="toggleSelectAll"
              />
            </th>
            <th class="px-4 py-3 font-medium text-neutral-500">Imagen</th>
            <th class="px-4 py-3">
              <button
                class="inline-flex items-center gap-1 font-medium text-neutral-500 transition-colors hover:text-neutral-900"
                @click="setSort('name')"
              >
                Nombre
                <ChevronUp v-if="sortKey === 'name' && sortDir === 'asc'" class="size-3.5" />
                <ChevronDown v-else-if="sortKey === 'name' && sortDir === 'desc'" class="size-3.5" />
                <ChevronsUpDown v-else class="size-3.5 opacity-40" />
              </button>
            </th>
            <th class="px-4 py-3">
              <button
                class="inline-flex items-center gap-1 font-medium text-neutral-500 transition-colors hover:text-neutral-900"
                @click="setSort('price')"
              >
                Precio
                <ChevronUp v-if="sortKey === 'price' && sortDir === 'asc'" class="size-3.5" />
                <ChevronDown v-else-if="sortKey === 'price' && sortDir === 'desc'" class="size-3.5" />
                <ChevronsUpDown v-else class="size-3.5 opacity-40" />
              </button>
            </th>
            <th class="px-4 py-3">
              <button
                class="inline-flex items-center gap-1 font-medium text-neutral-500 transition-colors hover:text-neutral-900"
                @click="setSort('stock')"
              >
                Stock
                <ChevronUp v-if="sortKey === 'stock' && sortDir === 'asc'" class="size-3.5" />
                <ChevronDown v-else-if="sortKey === 'stock' && sortDir === 'desc'" class="size-3.5" />
                <ChevronsUpDown v-else class="size-3.5 opacity-40" />
              </button>
            </th>
            <th class="px-4 py-3 font-medium text-neutral-500">Contacto</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Jornadas</th>
            <th class="px-4 py-3">
              <button
                class="inline-flex items-center gap-1 font-medium text-neutral-500 transition-colors hover:text-neutral-900"
                @click="setSort('estado')"
              >
                Estado
                <ChevronUp v-if="sortKey === 'estado' && sortDir === 'asc'" class="size-3.5" />
                <ChevronDown v-else-if="sortKey === 'estado' && sortDir === 'desc'" class="size-3.5" />
                <ChevronsUpDown v-else class="size-3.5 opacity-40" />
              </button>
            </th>
            <th class="px-4 py-3 font-medium text-neutral-500">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-neutral-50">
          <tr
            v-for="product in paginated"
            :key="product.id"
            class="transition-colors hover:bg-neutral-50/50"
          >
            <td class="px-4 py-3">
              <input
                type="checkbox"
                :checked="selected.has(product.id)"
                class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
                :aria-label="'Seleccionar ' + product.name"
                @change="toggleSelect(product.id)"
              />
            </td>
            <td class="px-4 py-3">
              <div
                v-if="product.product_image_path"
                class="size-10 overflow-hidden rounded-lg bg-neutral-100"
              >
                <img
                  :src="productImageUrl(product.product_image_path)"
                  alt=""
                  class="size-full object-cover"
                />
              </div>
              <div
                v-else
                class="flex size-10 items-center justify-center rounded-lg bg-neutral-100 text-xs text-neutral-400"
              >
                -
              </div>
            </td>
            <td class="px-4 py-3">
              <p class="font-medium text-neutral-900">{{ product.name }}</p>
              <p class="text-xs text-neutral-400 line-clamp-1">{{ product.description }}</p>
            </td>
            <td class="px-4 py-3 font-medium text-neutral-700 tabular-nums">
              <PriceDisplay :price="product.price" />
            </td>
            <td class="px-4 py-3">
              <span class="tabular-nums" :class="stockMeta(product).numCls">
                {{ product.stock }}
              </span>
              <span
                v-if="stockMeta(product).badge"
                class="ml-1.5 rounded-full px-2 py-0.5 text-[10px] font-medium"
                :class="stockMeta(product).badgeCls"
              >
                {{ stockMeta(product).badge }}
              </span>
            </td>
            <td class="px-4 py-3 text-neutral-600 tabular-nums">
              <span v-if="product.contact_phone">{{ product.contact_phone }}</span>
              <span v-else class="text-neutral-300">—</span>
            </td>
            <td class="px-4 py-3">
              <span
                v-if="product.jornadas?.length > 0"
                class="cursor-help text-neutral-600"
                :title="product.jornadas.join(' · ')"
              >
                {{ product.jornadas.length }}
              </span>
              <span v-else class="text-neutral-300">—</span>
            </td>
            <td class="px-4 py-3">
              <span
                v-if="product.is_active !== false"
                class="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-medium text-emerald-600"
              >
                Activo
              </span>
              <span
                v-else
                class="rounded-full bg-neutral-100 px-2 py-0.5 text-[10px] font-medium text-neutral-500"
              >
                Inactivo
              </span>
            </td>
            <td class="px-4 py-3">
              <div class="flex items-center gap-1">
                <a
                  v-if="product.is_active !== false"
                  :href="`/productos/${product.id}`"
                  target="_blank"
                  rel="noopener"
                  class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                  aria-label="Ver en la tienda"
                  :title="'Ver en la tienda: ' + product.name"
                >
                  <ExternalLink class="size-4" />
                </a>
                <button
                  class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                  @click="openEditDialog(product)"
                  aria-label="Editar"
                >
                  <Pencil class="size-4" />
                </button>
                <button
                  class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100"
                  @click="toggleActive(product.id)"
                  :aria-label="product.is_active !== false ? 'Desactivar' : 'Activar'"
                >
                  <EyeOff v-if="product.is_active !== false" class="size-4" />
                  <Eye v-else class="size-4" />
                </button>
                <button
                  class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-red-50 hover:text-red-600"
                  @click="openDeleteDialog(product)"
                  aria-label="Eliminar"
                >
                  <Trash2 class="size-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="mt-6 space-y-3 lg:hidden">
      <div
        v-for="product in paginated"
        :key="product.id"
        class="rounded-xl border border-neutral-200 bg-white p-4"
      >
        <div class="flex items-start gap-3">
          <input
            type="checkbox"
            :checked="selected.has(product.id)"
            class="mt-1 size-4 shrink-0 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
            :aria-label="'Seleccionar ' + product.name"
            @change="toggleSelect(product.id)"
          />
          <div
            v-if="product.product_image_path"
            class="size-12 shrink-0 overflow-hidden rounded-lg bg-neutral-100"
          >
            <img
              :src="productImageUrl(product.product_image_path)"
              alt=""
              class="size-full object-cover"
            />
          </div>
          <div
            v-else
            class="flex size-12 shrink-0 items-center justify-center rounded-lg bg-neutral-100 text-xs text-neutral-400"
          >
            -
          </div>

          <div class="min-w-0 flex-1">
            <div class="flex items-start justify-between gap-2">
              <p class="font-medium text-neutral-900">{{ product.name }}</p>
              <span
                v-if="product.is_active !== false"
                class="shrink-0 rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-medium text-emerald-600"
              >
                Activo
              </span>
              <span
                v-else
                class="shrink-0 rounded-full bg-neutral-100 px-2 py-0.5 text-[10px] font-medium text-neutral-500"
              >
                Inactivo
              </span>
            </div>
            <p v-if="product.description" class="mt-0.5 line-clamp-1 text-xs text-neutral-400">
              {{ product.description }}
            </p>

            <div class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
              <span class="font-medium text-neutral-700 tabular-nums">
                <PriceDisplay :price="product.price" />
              </span>
              <span class="tabular-nums" :class="stockMeta(product).numCls">
                Stock: {{ product.stock }}
              </span>
              <span
                v-if="stockMeta(product).badge"
                class="rounded-full px-2 py-0.5 text-[10px] font-medium"
                :class="stockMeta(product).badgeCls"
              >
                {{ stockMeta(product).badge }}
              </span>
            </div>

            <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-neutral-500">
              <span v-if="product.contact_phone">WhatsApp: {{ product.contact_phone }}</span>
              <span v-if="product.jornadas?.length > 0">
                {{ product.jornadas.length }}
                {{ product.jornadas.length === 1 ? 'jornada' : 'jornadas' }}
              </span>
            </div>

            <div class="mt-3 flex items-center gap-1">
              <a
                v-if="product.is_active !== false"
                :href="`/productos/${product.id}`"
                target="_blank"
                rel="noopener"
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                aria-label="Ver en la tienda"
                :title="'Ver en la tienda: ' + product.name"
              >
                <ExternalLink class="size-4" />
              </a>
              <button
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                @click="openEditDialog(product)"
                aria-label="Editar"
              >
                <Pencil class="size-4" />
              </button>
              <button
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100"
                @click="toggleActive(product.id)"
                :aria-label="product.is_active !== false ? 'Desactivar' : 'Activar'"
              >
                <EyeOff v-if="product.is_active !== false" class="size-4" />
                <Eye v-else class="size-4" />
              </button>
              <button
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-red-50 hover:text-red-600"
                @click="openDeleteDialog(product)"
                aria-label="Eliminar"
              >
                <Trash2 class="size-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="sortedProducts.length > 0" class="mt-4 flex items-center justify-between">
      <div class="flex items-center gap-2 text-sm text-neutral-500">
        <span>Filas por página</span>
        <select
          v-model.number="pageSize"
          class="h-8 rounded-md border border-neutral-200 bg-white px-2 text-sm text-neutral-700 outline-none focus:border-ucla-400"
        >
          <option :value="10">10</option>
          <option :value="25">25</option>
          <option :value="50">50</option>
        </select>
      </div>
      <div class="flex items-center gap-1">
        <Button
          size="sm"
          variant="outline"
          :disabled="page <= 1"
          @click="page--"
          aria-label="Página anterior"
        >
          <ChevronLeft class="size-4" />
        </Button>
        <span class="px-2 text-sm tabular-nums text-neutral-600">{{ page }} / {{ totalPages }}</span>
        <Button
          size="sm"
          variant="outline"
          :disabled="page >= totalPages"
          @click="page++"
          aria-label="Página siguiente"
        >
          <ChevronRight class="size-4" />
        </Button>
      </div>
    </div>
  </div>

  <Dialog v-model:open="dialogOpen">
    <DialogScrollContent class="sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>{{ editingProduct ? 'Editar producto' : 'Nuevo producto' }}</DialogTitle>
        <DialogDescription>
          {{
            editingProduct
              ? 'Modificá los datos del producto.'
              : 'Completá los datos del nuevo producto.'
          }}
        </DialogDescription>
      </DialogHeader>

      <form id="product-form" @submit.prevent="handleSave" class="space-y-4">
        <div class="grid gap-2">
          <Label>Imagen</Label>
          <div class="flex items-start gap-3">
            <label
              class="relative flex size-24 shrink-0 items-center justify-center overflow-hidden rounded-lg border-2 transition-colors"
              :class="
                dragOver
                  ? 'border-ucla-500 bg-ucla-50'
                  : 'border-dashed border-neutral-300 bg-neutral-50'
              "
              @dragover.prevent="dragOver = true"
              @dragleave.prevent="dragOver = false"
              @drop.prevent="onDrop"
            >
              <input
                ref="imageInput"
                type="file"
                accept="image/*"
                class="absolute inset-0 z-0 h-full w-full cursor-pointer opacity-0"
                @change="onImageSelected"
              />
              <span class="pointer-events-none relative z-10 flex size-full items-center justify-center">
                <img
                  v-if="imagePreview"
                  :src="imagePreview"
                  class="size-full object-cover"
                  alt="Preview"
                />
                <div v-else class="flex flex-col items-center gap-1">
                  <ImageUp class="size-6 text-neutral-300" />
                  <span class="text-[10px] text-neutral-400">Click o arrastra</span>
                </div>
              </span>
            </label>
            <div class="flex flex-col gap-1.5 pt-1">
              <Button type="button" variant="outline" size="sm" @click="imageInput?.click()">
                <ImageUp class="size-3.5" />
                {{ imagePreview ? 'Cambiar' : 'Subir imagen' }}
              </Button>
              <Button
                v-if="imagePreview"
                type="button"
                variant="ghost"
                size="sm"
                class="text-red-500 hover:text-red-600"
                @click="removeImage"
              >
                <Trash2 class="size-3.5" />
                Eliminar
              </Button>
            </div>
          </div>
        </div>

        <div class="grid gap-2">
          <Label for="prod-name">Nombre *</Label>
          <Input
            id="prod-name"
            v-model="form.name"
            placeholder="Nombre del producto"
            :class="formErrors.name ? 'border-red-400 focus-visible:ring-red-500/30' : ''"
            required
          />
          <p v-if="formErrors.name" class="text-xs text-red-500">{{ formErrors.name }}</p>
        </div>

        <div class="grid gap-2">
          <Label for="prod-desc">Descripción</Label>
          <Textarea
            id="prod-desc"
            v-model="form.description"
            placeholder="Descripción del producto"
            :class="formErrors.description ? 'border-red-400 focus-visible:ring-red-500/30' : ''"
          />
          <p v-if="formErrors.description" class="text-xs text-red-500">
            {{ formErrors.description }}
          </p>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="grid gap-2">
            <Label for="prod-price">Precio *</Label>
            <Input
              id="prod-price"
              v-model="form.price"
              type="number"
              step="0.01"
              min="0"
              placeholder="0.00"
              :class="formErrors.price ? 'border-red-400 focus-visible:ring-red-500/30' : ''"
              required
            />
            <p v-if="formErrors.price" class="text-xs text-red-500">{{ formErrors.price }}</p>
          </div>
          <div class="grid gap-2">
            <Label for="prod-stock">Stock</Label>
            <Input
              id="prod-stock"
              v-model="form.stock"
              type="number"
              min="0"
              placeholder="0"
              :class="formErrors.stock ? 'border-red-400 focus-visible:ring-red-500/30' : ''"
            />
            <p v-if="formErrors.stock" class="text-xs text-red-500">{{ formErrors.stock }}</p>
          </div>
        </div>

        <div class="grid gap-2">
          <Label for="prod-contact">Número de contacto (WhatsApp)</Label>
          <Input
            id="prod-contact"
            v-model="form.contact_phone"
            type="tel"
            placeholder="0412-1234567"
          />
          <p class="text-xs text-neutral-400">
            Los pedidos de este producto se envían por WhatsApp a este número.
          </p>
        </div>

        <div class="flex items-center gap-4">
          <label class="flex items-center gap-2 text-sm">
            <input
              v-model="form.allow_backorder"
              type="checkbox"
              class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
            />
            Permitir backorder
          </label>
          <label class="flex items-center gap-2 text-sm">
            <input
              v-model="form.is_active"
              type="checkbox"
              class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
            />
            Activo
          </label>
        </div>

        <div v-if="editingProduct" class="grid gap-2">
          <Label>Jornadas</Label>
          <div v-if="editingProduct.jornadas?.length" class="flex flex-wrap gap-1.5">
            <span
              v-for="name in editingProduct.jornadas"
              :key="name"
              class="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-600"
            >
              {{ name }}
            </span>
          </div>
          <p v-else class="text-sm text-neutral-400">
            No está asociado a ninguna jornada.
          </p>
          <router-link to="/admin/jornadas" class="text-xs text-ucla-600 underline">
            Administrar jornadas
          </router-link>
        </div>

        <div class="grid gap-2">
          <Label>Cuentas de pago</Label>
          <div
            v-if="paymentAccounts.length > 0"
            class="max-h-40 space-y-1.5 overflow-y-auto rounded-lg border border-neutral-200 p-2"
          >
            <label
              v-for="acct in paymentAccounts"
              :key="acct.id"
              class="flex cursor-pointer items-center gap-3 rounded-md px-2 py-1.5 text-sm transition-colors hover:bg-neutral-50"
              :class="{ 'bg-ucla-50': form.payment_account_ids.includes(acct.id) }"
            >
              <input
                type="checkbox"
                :checked="form.payment_account_ids.includes(acct.id)"
                class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
                @change="togglePaymentAccount(acct.id)"
              />
              <span class="flex-1">{{ acct.name }}</span>
              <span class="text-xs text-neutral-400">{{ acct.bank }}</span>
            </label>
          </div>
          <p v-else class="text-sm text-neutral-400">
            No hay cuentas de pago activas.
            <router-link to="/admin/cuentas-pago" class="text-ucla-600 underline">
              Crear cuenta
            </router-link>
          </p>
        </div>
      </form>

      <DialogFooter>
        <Button type="submit" form="product-form" :disabled="saving">
          {{ saving ? 'Guardando...' : editingProduct ? 'Guardar cambios' : 'Crear producto' }}
        </Button>
      </DialogFooter>
    </DialogScrollContent>
  </Dialog>

  <Dialog v-model:open="deleteDialogOpen">
    <DialogContent class="sm:max-w-sm">
      <DialogHeader>
        <DialogTitle>Eliminar {{ deleteTarget ? 'producto' : 'productos' }}</DialogTitle>
        <DialogDescription>
          <template v-if="deleteTarget">
            ¿Seguro que querés eliminar "<strong>{{ deleteTarget.name }}</strong>"? Se conservará el
            historial de pedidos, pero esta acción no se puede deshacer.
          </template>
          <template v-else>
            ¿Seguro que querés eliminar los {{ deleteBulkCount }} productos seleccionados? Se
            conservará el historial de pedidos, pero esta acción no se puede deshacer.
          </template>
        </DialogDescription>
      </DialogHeader>
      <DialogFooter>
        <Button variant="outline" :disabled="saving" @click="deleteDialogOpen = false">
          Cancelar
        </Button>
        <Button
          variant="destructive"
          :disabled="saving"
          @click="confirmDelete"
        >
          {{ saving ? 'Eliminando...' : 'Eliminar' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>