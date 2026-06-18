<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Save, ArrowLeft } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const route = useRoute()
const router = useRouter()
const isEdit = route.name === 'admin-payment-account-edit'

const form = ref({
  id: null,
  name: '',
  holder_name: '',
  bank: '',
  phone: '',
  ci: '',
  account_type: 'personal',
  is_active: true,
})

onMounted(async () => {
  if (isEdit) {
    const id = route.params.id
    const { data, error } = await supabase
      .from('payment_accounts')
      .select('*')
      .eq('id', id)
      .single()
    if (error) {
      console.error('loadAccount', error)
      toast.error('No se pudo cargar la cuenta')
    } else form.value = { ...data }
  }
})

async function handleSave() {
  try {
    if (isEdit) {
      const { error } = await supabase
        .from('payment_accounts')
        .update({
          name: form.value.name,
          holder_name: form.value.holder_name,
          bank: form.value.bank,
          phone: form.value.phone,
          ci: form.value.ci,
          account_type: form.value.account_type,
          is_active: form.value.is_active,
        })
        .eq('id', form.value.id || route.params.id)
      if (error) {
        console.error('updateAccount', error)
        toast.error('No se pudo actualizar la cuenta')
        return
      }
      toast.success('Cuenta actualizada')
    } else {
      const { error } = await supabase.from('payment_accounts').insert([
        {
          name: form.value.name,
          holder_name: form.value.holder_name,
          bank: form.value.bank,
          phone: form.value.phone,
          ci: form.value.ci,
          account_type: form.value.account_type,
          is_active: form.value.is_active,
        },
      ])
      if (error) {
        console.error('createAccount', error)
        toast.error('No se pudo crear la cuenta')
        return
      }
      toast.success('Cuenta creada')
    }
    router.push('/admin/cuentas-pago')
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <router-link
      to="/admin/cuentas-pago"
      class="inline-flex items-center gap-1.5 text-sm text-neutral-500 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver a cuentas
    </router-link>

    <h1 class="mt-4 text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
      {{ isEdit ? 'Editar cuenta' : 'Nueva cuenta de pago' }}
    </h1>

    <form class="mt-8 space-y-5" @submit.prevent="handleSave">
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Nombre *</label>
        <Input v-model="form.name" type="text" placeholder="Ej: Mercantil Principal" required />
      </div>

      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Titular</label>
        <Input v-model="form.holder_name" type="text" placeholder="Nombre del titular" />
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600">Banco</label>
          <Input v-model="form.bank" type="text" placeholder="Ej: Mercantil" />
        </div>
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600">Teléfono</label>
          <Input v-model="form.phone" type="tel" placeholder="0412-1234567" />
        </div>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600">CI / RIF</label>
          <Input v-model="form.ci" type="text" placeholder="V-12345678" />
        </div>
        <div>
          <label class="mb-1.5 block text-xs font-medium text-neutral-600">Tipo</label>
          <select
            v-model="form.account_type"
            class="h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm transition-colors focus:border-ring focus:ring-3 focus:ring-ring/50 focus:outline-none"
          >
            <option value="personal">Personal</option>
            <option value="juridica">Jurídica</option>
            <option value="institucional">Institucional</option>
          </select>
        </div>
      </div>

      <label class="flex items-center gap-2">
        <input
          v-model="form.is_active"
          type="checkbox"
          class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
        />
        <span class="text-sm text-neutral-700">Cuenta activa</span>
      </label>

      <div class="flex gap-3 pt-4">
        <Button type="submit">
          <Save class="size-4" />
          {{ isEdit ? 'Guardar cambios' : 'Crear cuenta' }}
        </Button>
        <Button type="button" variant="outline" @click="router.push('/admin/cuentas-pago')">
          Cancelar
        </Button>
      </div>
    </form>
  </div>
</template>
