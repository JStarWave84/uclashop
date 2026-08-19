<script setup>
import { ref, computed, onMounted } from 'vue'
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
  Lock,
  ShieldCheck,
} from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { optimizeProductImage } from '@/lib/imageOptimize'
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
import { validateProduct } from '@/schemas/product'
import { useAuthStore } from '@/stores/auth'
import { productImageUrl } from '@/lib/storage'

const LOW_STOCK = 5

const auth = useAuthStore()
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
})

const imageInput = ref(null)
const imageFile = ref(null)
const imagePreview = ref(null)
const dragOver = ref(false)

const canManage = computed(() => auth.isVerifiedStore)

async function fetchProducts() {
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .eq('store_id', auth.storeId)
    .order('created_at', { ascending: false })
  if (error) {
    console.error('fetchProducts', error)
    products.value = []
    toast.error('Error cargando productos')
    return
  }
  products.value = data || []
}

onMounted(fetchProducts)

const filteredProducts = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return products.value
  return products.value.filter((p) =>
    `${p.name || ''} ${p.description || ''}`.toLowerCase().includes(q)
  )
})

function stockMeta(p) {
  if (p.stock === 0 && p.allow_backorder)
    return { badge: 'Backorder', badgeCls: 'bg-ucla-gold/10 text-ucla-gold', numCls: 'text-ucla-gold' }
  if (p.stock === 0)
    return { badge: 'Agotado', badgeCls: 'bg-red-50 text-red-600', numCls: 'text-red-600' }
  if (p.stock <= LOW_STOCK)
    return { badge: 'Bajo', badgeCls: 'bg-amber-50 text-amber-600', numCls: 'text-amber-600' }
  return { badge: null, badgeCls: '', numCls: 'text-neutral-700' }
}

function resetForm() {
  form.value = { name: '', description: '', price: '', stock: 0, allow_backorder: false, is_active: true }
  formErrors.value = {}
  imageFile.value = null
  imagePreview.value = null
}

function openNewDialog() {
  editingProduct.value = null
  resetForm()
  dialogOpen.value = true
}

function openEditDialog(product) {
  editingProduct.value = product
  form.value = {
    name: product.name || '',
    description: product.description || '',
    price: product.price ?? '',
    stock: product.stock ?? 0,
    allow_backorder: product.allow_backorder ?? false,
    is_active: product.is_active ?? true,
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
  const optimized = await optimizeProductImage(imageFile.value)
  const ext = optimized.name.split('.').pop()
  const path = `${productId}/${Date.now()}.${ext}`
  const { error } = await supabase.storage
    .from('product-images')
    .upload(path, optimized, { upsert: true })
  if (error) {
    console.error('uploadImage', error)
    throw error
  }
  return path
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
      store_id: auth.storeId,
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

async function toggleActive(id) {
  const p = products.value.find((x) => x.id === id)
  if (!p) return
  const { error } = await supabase.from('products').update({ is_active: !p.is_active }).eq('id', id)
  if (error) {
    console.error('toggleActive', error)
    toast.error('No se pudo actualizar el estado')
  } else {
    p.is_active = !p.is_active
    toast.success('Estado actualizado')
  }
}

async function handleDelete(id) {
  const p = products.value.find((x) => x.id === id)
  if (!p) return
  try {
    if (p.product_image_path) {
      await supabase.storage.from('product-images').remove([p.product_image_path]).catch(() => {})
    }
    const { error } = await supabase.from('products').delete().eq('id', id)
    if (error) {
      toast.error('Error eliminando producto')
      console.error(error)
      return
    }
    toast.success('Producto eliminado')
    await fetchProducts()
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  }
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Mis productos
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
          <Input v-model="search" type="search" placeholder="Buscar productos..." class="w-48 pl-9 sm:w-56" />
        </div>
        <Button :disabled="!canManage" @click="openNewDialog" :title="canManage ? '' : 'Esperá la verificación'">
          <Plus class="size-4" />
          Nuevo
        </Button>
      </div>
    </div>

    <div
      v-if="!canManage"
      class="mt-6 flex items-center gap-3 rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-700"
    >
      <Lock class="size-4 shrink-0" />
      Tu tienda aún no está verificada. Cuando el Centro de Estudiantes la apruebe podrás publicar
      productos.
    </div>

    <div
      v-else-if="auth.isVerifiedStore"
      class="mt-6 flex items-center gap-3 rounded-xl border border-emerald-200 bg-emerald-50 px-5 py-4 text-sm text-emerald-700"
    >
      <ShieldCheck class="size-4 shrink-0" />
      Tu tienda está verificada. Podés publicar y gestionar tu inventario.
    </div>

    <div v-if="filteredProducts.length === 0" class="mt-10 rounded-xl border border-neutral-200 bg-white py-14 text-center">
      <Search class="mx-auto size-8 text-neutral-300" />
      <p class="mt-3 text-sm text-neutral-500">
        {{ canManage ? 'Todavía no tenés productos. ¡Creá el primero!' : 'No hay productos todavía.' }}
      </p>
    </div>

    <div v-else class="mt-6 space-y-3">
      <div
        v-for="product in filteredProducts"
        :key="product.id"
        class="flex items-center gap-4 rounded-xl border border-neutral-200 bg-white p-4"
      >
        <div
          v-if="product.product_image_path"
          class="size-14 shrink-0 overflow-hidden rounded-lg bg-neutral-100"
        >
          <img :src="productImageUrl(product.product_image_path)" alt="" class="size-full object-cover" />
        </div>
        <div
          v-else
          class="flex size-14 shrink-0 items-center justify-center rounded-lg bg-neutral-100 text-xs text-neutral-400"
        >
          -
        </div>

        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <p class="truncate font-medium text-neutral-900">{{ product.name }}</p>
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
          <p class="mt-0.5 line-clamp-1 text-xs text-neutral-400">{{ product.description }}</p>
          <div class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
            <span class="font-medium text-neutral-700 tabular-nums">
              <PriceDisplay :price="product.price" />
            </span>
            <span class="tabular-nums" :class="stockMeta(product).numCls">Stock: {{ product.stock }}</span>
            <span
              v-if="stockMeta(product).badge"
              class="rounded-full px-2 py-0.5 text-[10px] font-medium"
              :class="stockMeta(product).badgeCls"
            >
              {{ stockMeta(product).badge }}
            </span>
          </div>
        </div>

        <div class="flex shrink-0 items-center gap-1">
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
            class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600 disabled:cursor-not-allowed disabled:opacity-40"
            :disabled="!canManage"
            @click="openEditDialog(product)"
            aria-label="Editar"
          >
            <Pencil class="size-4" />
          </button>
          <button
            class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 disabled:cursor-not-allowed disabled:opacity-40"
            :disabled="!canManage"
            @click="toggleActive(product.id)"
            :aria-label="product.is_active !== false ? 'Desactivar' : 'Activar'"
          >
            <EyeOff v-if="product.is_active !== false" class="size-4" />
            <Eye v-else class="size-4" />
          </button>
          <button
            class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-red-50 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-40"
            :disabled="!canManage"
            @click="handleDelete(product.id)"
            aria-label="Eliminar"
          >
            <Trash2 class="size-4" />
          </button>
        </div>
      </div>
    </div>

    <Dialog v-model:open="dialogOpen">
      <DialogScrollContent class="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{{ editingProduct ? 'Editar producto' : 'Nuevo producto' }}</DialogTitle>
          <DialogDescription>
            {{ editingProduct ? 'Modificá los datos del producto.' : 'Completá los datos del nuevo producto.' }}
          </DialogDescription>
        </DialogHeader>

        <form id="store-product-form" @submit.prevent="handleSave" class="space-y-4">
          <div class="grid gap-2">
            <Label>Imagen</Label>
            <div class="flex items-start gap-3">
              <label
                class="relative flex size-24 shrink-0 items-center justify-center overflow-hidden rounded-lg border-2 transition-colors"
                :class="dragOver ? 'border-ucla-500 bg-ucla-50' : 'border-dashed border-neutral-300 bg-neutral-50'"
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
                  <img v-if="imagePreview" :src="imagePreview" class="size-full object-cover" alt="Preview" />
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
            <Label for="sp-name">Nombre *</Label>
            <Input
              id="sp-name"
              v-model="form.name"
              placeholder="Nombre del producto"
              :class="formErrors.name ? 'border-red-400' : ''"
              required
            />
            <p v-if="formErrors.name" class="text-xs text-red-500">{{ formErrors.name }}</p>
          </div>

          <div class="grid gap-2">
            <Label for="sp-desc">Descripción</Label>
            <Textarea
              id="sp-desc"
              v-model="form.description"
              placeholder="Descripción del producto"
              :class="formErrors.description ? 'border-red-400' : ''"
            />
            <p v-if="formErrors.description" class="text-xs text-red-500">{{ formErrors.description }}</p>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div class="grid gap-2">
              <Label for="sp-price">Precio *</Label>
              <Input
                id="sp-price"
                v-model="form.price"
                type="number"
                step="0.01"
                min="0"
                placeholder="0.00"
                :class="formErrors.price ? 'border-red-400' : ''"
                required
              />
              <p v-if="formErrors.price" class="text-xs text-red-500">{{ formErrors.price }}</p>
            </div>
            <div class="grid gap-2">
              <Label for="sp-stock">Stock</Label>
              <Input
                id="sp-stock"
                v-model="form.stock"
                type="number"
                min="0"
                placeholder="0"
                :class="formErrors.stock ? 'border-red-400' : ''"
              />
              <p v-if="formErrors.stock" class="text-xs text-red-500">{{ formErrors.stock }}</p>
            </div>
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
        </form>

        <DialogFooter>
          <Button type="submit" form="store-product-form" :disabled="saving">
            {{ saving ? 'Guardando...' : editingProduct ? 'Guardar cambios' : 'Crear producto' }}
          </Button>
        </DialogFooter>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>