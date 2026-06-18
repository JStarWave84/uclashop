<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { Plus, Search, Pencil, EyeOff, Eye, Trash2, ImageUp } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import PriceDisplay from '@/components/shared/PriceDisplay.vue'

const search = ref('')
const products = ref([])
const dialogOpen = ref(false)
const saving = ref(false)
const editingProduct = ref(null)

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
  } else {
    products.value = data || []
  }
}

onMounted(fetchProducts)

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return products.value
  return products.value.filter(
    (p) =>
      (p.name || '').toLowerCase().includes(q) || (p.description || '').toLowerCase().includes(q)
  )
})

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

function openNewDialog() {
  editingProduct.value = null
  form.value = {
    name: '',
    description: '',
    price: '',
    stock: 0,
    allow_backorder: false,
    is_active: true,
  }
  imageFile.value = null
  imagePreview.value = null
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
  imageFile.value = null
  imagePreview.value = product.product_image_path
    ? productImageUrl(product.product_image_path)
    : null
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

async function handleSave() {
  if (!form.value.name.trim()) {
    toast.error('El nombre es requerido')
    return
  }
  saving.value = true
  try {
    if (editingProduct.value) {
      const updates = {
        name: form.value.name,
        description: form.value.description,
        price: form.value.price,
        stock: form.value.stock,
        allow_backorder: form.value.allow_backorder,
        is_active: form.value.is_active,
      }
      if (imageFile.value) {
        const path = await uploadImage(editingProduct.value.id)
        updates.product_image_path = path
      } else if (imagePreview.value === null && editingProduct.value.product_image_path) {
        const oldPath = editingProduct.value.product_image_path
        await supabase.storage
          .from('product-images')
          .remove([oldPath])
          .catch(() => {})
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
        .insert([
          {
            name: form.value.name,
            description: form.value.description,
            price: form.value.price,
            stock: form.value.stock,
            allow_backorder: form.value.allow_backorder,
            is_active: form.value.is_active,
          },
        ])
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
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Productos
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtered.length }} {{ filtered.length === 1 ? 'producto' : 'productos' }}
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

    <div class="mt-6 overflow-hidden rounded-xl border border-neutral-200 bg-white">
      <table class="w-full text-left text-sm">
        <thead class="border-b border-neutral-100 bg-neutral-50/50">
          <tr>
            <th class="px-4 py-3 font-medium text-neutral-500">Imagen</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Nombre</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Precio</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Stock</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Estado</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-neutral-50">
          <tr
            v-for="product in filtered"
            :key="product.id"
            class="transition-colors hover:bg-neutral-50/50"
          >
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
              <span
                class="tabular-nums"
                :class="product.stock === 0 ? 'text-amber-600' : 'text-neutral-700'"
              >
                {{ product.stock }}
              </span>
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
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <Dialog v-model:open="dialogOpen">
    <DialogContent class="sm:max-w-lg">
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
              <span
                class="relative z-10 flex size-full items-center justify-center pointer-events-none"
              >
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
          <Input id="prod-name" v-model="form.name" placeholder="Nombre del producto" required />
        </div>

        <div class="grid gap-2">
          <Label for="prod-desc">Descripción</Label>
          <Textarea
            id="prod-desc"
            v-model="form.description"
            placeholder="Descripción del producto"
          />
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
              required
            />
          </div>
          <div class="grid gap-2">
            <Label for="prod-stock">Stock</Label>
            <Input id="prod-stock" v-model="form.stock" type="number" min="0" placeholder="0" />
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
        <Button type="submit" form="product-form" :disabled="saving">
          {{ saving ? 'Guardando...' : editingProduct ? 'Guardar cambios' : 'Crear producto' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
