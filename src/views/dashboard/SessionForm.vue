<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Save, ArrowLeft, Package } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const products = ref([])

const route = useRoute()
const router = useRouter()
const isEdit = route.name === 'admin-session-edit'
const form = ref({
  id: null,
  name: '',
  start_date: '',
  end_date: '',
  is_open: true,
  product_ids: [],
})

onMounted(async () => {
  // fetch products for selection
  const { data: prods, error: pErr } = await supabase
    .from('products')
    .select('id, name, price')
    .order('name')
  if (pErr) {
    console.error('loadProducts', pErr)
    toast.error('No se pudieron cargar productos')
  } else products.value = prods || []

  if (isEdit) {
    const id = route.params.id
    const { data, error } = await supabase.from('sales_sessions').select('*').eq('id', id).single()
    if (error) {
      console.error('loadSession', error)
      toast.error('No se pudo cargar la jornada')
    } else if (data) {
      form.value = {
        id: data.id,
        name: data.name,
        start_date: data.start_date?.slice(0, 10) || '',
        end_date: data.end_date?.slice(0, 10) || '',
        is_open: data.is_open,
        product_ids: [],
      }
      // load product_sessions
      const { data: ps, error: psErr } = await supabase
        .from('product_sessions')
        .select('product_id')
        .eq('session_id', id)
      if (psErr) {
        console.error('loadProductSessions', psErr)
      } else form.value.product_ids = (ps || []).map((x) => x.product_id)
    }
  }
})

function toggleProduct(id) {
  const idx = form.value.product_ids.indexOf(id)
  if (idx >= 0) form.value.product_ids.splice(idx, 1)
  else form.value.product_ids.push(id)
}

async function handleSave() {
  try {
    if (isEdit) {
      const { error } = await supabase
        .from('sales_sessions')
        .update({
          name: form.value.name,
          start_date: form.value.start_date,
          end_date: form.value.end_date,
          is_open: form.value.is_open,
        })
        .eq('id', form.value.id || route.params.id)
      if (error) {
        toast.error('Error actualizando jornada')
        console.error(error)
        return
      }
      // replace product_sessions for this session
      const sid = form.value.id || route.params.id
      const { error: delErr } = await supabase
        .from('product_sessions')
        .delete()
        .eq('session_id', sid)
      if (delErr) {
        console.error('deleteProductSessions', delErr)
      }
      for (const pid of form.value.product_ids) {
        const { error: insErr } = await supabase
          .from('product_sessions')
          .insert([{ product_id: pid, session_id: sid }])
        if (insErr) console.error('insertProductSession', insErr)
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
          const { error: insErr } = await supabase
            .from('product_sessions')
            .insert([{ product_id: pid, session_id: sid }])
          if (insErr) console.error('insertProductSession', insErr)
        }
      }
      toast.success('Jornada creada')
    }
    router.push('/admin/jornadas')
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <router-link
      to="/admin/jornadas"
      class="inline-flex items-center gap-1.5 text-sm text-neutral-500 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver a jornadas
    </router-link>

    <h1 class="mt-4 text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
      {{ isEdit ? 'Editar jornada' : 'Nueva jornada' }}
    </h1>

    <form class="mt-8 space-y-5" @submit.prevent="handleSave">
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Nombre *</label>
        <Input v-model="form.name" type="text" placeholder="Ej: Jornada de julio" required />
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600">Fecha inicio *</label>
          <Input v-model="form.start_date" type="date" required />
        </div>
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600">Fecha fin *</label>
          <Input v-model="form.end_date" type="date" required />
        </div>
      </div>

      <label class="flex items-center gap-2">
        <input
          v-model="form.is_open"
          type="checkbox"
          class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
        />
        <span class="text-sm text-neutral-700">Jornada abierta</span>
      </label>

      <div>
        <p class="mb-3 text-xs font-medium text-neutral-600">Productos disponibles</p>
        <div class="space-y-1.5">
          <label
            v-for="product in products"
            :key="product.id"
            class="flex cursor-pointer items-center gap-3 rounded-lg border border-neutral-100 px-3 py-2 transition-colors hover:bg-neutral-50"
            :class="{ 'border-ucla-200 bg-ucla-50': form.product_ids.includes(product.id) }"
          >
            <input
              type="checkbox"
              :checked="form.product_ids.includes(product.id)"
              class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
              @change="toggleProduct(product.id)"
            />
            <div class="flex flex-1 items-center justify-between">
              <span class="text-sm text-neutral-900">{{ product.name }}</span>
              <span class="text-xs text-neutral-400">${{ product.price }}</span>
            </div>
          </label>
        </div>
      </div>

      <div class="flex gap-3 pt-4">
        <Button type="submit">
          <Save class="size-4" />
          {{ isEdit ? 'Guardar cambios' : 'Crear jornada' }}
        </Button>
        <Button type="button" variant="outline" @click="router.push('/admin/jornadas')">
          Cancelar
        </Button>
      </div>
    </form>
  </div>
</template>
