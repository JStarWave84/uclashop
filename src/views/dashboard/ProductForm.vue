<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Save, ArrowLeft, Package } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const route = useRoute()
const router = useRouter()
const isEdit = route.name === 'admin-product-edit'
const form = ref({
  id: null,
  name: '',
  description: '',
  price: '',
  stock: 0,
  allow_backorder: false,
  is_active: true,
})

onMounted(async () => {
  if (isEdit) {
    const id = route.params.id
    const { data, error } = await supabase.from('products').select('*').eq('id', id).single()
    if (error) {
      console.error('loadProduct', error)
      toast.error('No se pudo cargar el producto')
    } else if (data) {
      form.value = { ...data }
    }
  }
})

async function handleSave() {
  try {
    if (isEdit) {
      const { error } = await supabase
        .from('products')
        .update({
          name: form.value.name,
          description: form.value.description,
          price: form.value.price,
          stock: form.value.stock,
          allow_backorder: form.value.allow_backorder,
          is_active: form.value.is_active,
        })
        .eq('id', form.value.id || route.params.id)
      if (error) {
        toast.error('Error actualizando producto')
        console.error(error)
        return
      }
      toast.success('Producto actualizado')
    } else {
      const { error } = await supabase.from('products').insert([
        {
          name: form.value.name,
          description: form.value.description,
          price: form.value.price,
          stock: form.value.stock,
          allow_backorder: form.value.allow_backorder,
          is_active: form.value.is_active,
        },
      ])
      if (error) {
        toast.error('Error creando producto')
        console.error(error)
        return
      }
      toast.success('Producto creado')
    }
    router.push('/admin/productos')
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <router-link
      to="/admin/productos"
      class="inline-flex items-center gap-1.5 text-sm text-neutral-500 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver a productos
    </router-link>

    <h1 class="mt-4 text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
      {{ isEdit ? 'Editar producto' : 'Nuevo producto' }}
    </h1>

    <form class="mt-8 space-y-5" @submit.prevent="handleSave">
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600"> Nombre * </label>
        <Input v-model="form.name" type="text" placeholder="Nombre del producto" required />
      </div>

      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600"> Descripción </label>
        <textarea
          v-model="form.description"
          class="min-h-[80px] w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-xs transition-[color,box-shadow] outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
          placeholder="Descripción del producto"
        />
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600"> Precio * </label>
          <Input
            v-model="form.price"
            type="number"
            step="0.01"
            min="0"
            placeholder="0.00"
            required
          />
        </div>
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600"> Stock </label>
          <Input v-model="form.stock" type="number" min="0" placeholder="0" />
        </div>
      </div>

      <div class="flex items-center gap-6">
        <label class="flex items-center gap-2">
          <input
            v-model="form.allow_backorder"
            type="checkbox"
            class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
          />
          <span class="text-sm text-neutral-700">Permitir backorder</span>
        </label>
        <label class="flex items-center gap-2">
          <input
            v-model="form.is_active"
            type="checkbox"
            class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
          />
          <span class="text-sm text-neutral-700">Activo</span>
        </label>
      </div>

      <div class="flex gap-3 pt-4">
        <Button type="submit">
          <Save class="size-4" />
          {{ isEdit ? 'Guardar cambios' : 'Crear producto' }}
        </Button>
        <Button type="button" variant="outline" @click="router.push('/admin/productos')">
          Cancelar
        </Button>
      </div>
    </form>
  </div>
</template>
