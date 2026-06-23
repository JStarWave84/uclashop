<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Save, ArrowLeft } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const router = useRouter()

const form = ref({ name: 'Pago móvil', bank: '', holder_name: '', phone: '', ci: '' })

onMounted(async () => {
  const { data, error } = await supabase.from('payment_settings').select('*').limit(1).single()
  if (error && error.code !== 'PGRST116') {
    // single returns error when no rows
    console.error('loadPaymentSettings', error)
    toast.error('No se pudo cargar la configuración')
  } else if (data)
    form.value = {
      name: data.name || 'Pago móvil',
      bank: data.bank || '',
      holder_name: data.holder_name || '',
      phone: data.phone || '',
      ci: data.ci || '',
    }
})

async function handleSave() {
  try {
    // Upsert pattern: try update first by id if exists, otherwise insert
    const { data: existing } = await supabase
      .from('payment_settings')
      .select('id')
      .limit(1)
      .single()
    if (existing && existing.id) {
      const { error } = await supabase
        .from('payment_settings')
        .update({
          name: form.value.name,
          bank: form.value.bank,
          holder_name: form.value.holder_name,
          phone: form.value.phone,
          ci: form.value.ci,
        })
        .eq('id', existing.id)
      if (error) {
        console.error('savePaymentSettings', error)
        toast.error('No se pudo guardar')
        return
      }
    } else {
      const { error } = await supabase
        .from('payment_settings')
        .insert([{
          name: form.value.name,
          bank: form.value.bank,
          holder_name: form.value.holder_name,
          phone: form.value.phone,
          ci: form.value.ci,
        }])
      if (error) {
        console.error('createPaymentSettings', error)
        toast.error('No se pudo crear la configuración')
        return
      }
    }
    toast.success('Configuración guardada')
    router.push('/admin')
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <router-link
      to="/admin"
      class="inline-flex items-center gap-1.5 text-sm text-neutral-500 transition-colors hover:text-ucla-600"
    >
      <ArrowLeft class="size-4" />
      Volver al panel
    </router-link>

    <h1 class="mt-4 text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
      Configuración de pago
    </h1>
    <p class="mt-1 text-sm text-neutral-500">
      Información de pago global que se muestra por defecto a los clientes.
    </p>

    <form class="mt-8 space-y-5" @submit.prevent="handleSave">
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Nombre de la cuenta</label>
        <Input v-model="form.name" type="text" placeholder="Ej: Pago móvil" />
      </div>
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Banco</label>
        <Input v-model="form.bank" type="text" placeholder="Ej: Mercantil Banco" />
      </div>
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Titular</label>
        <Input v-model="form.holder_name" type="text" placeholder="Nombre del titular" />
      </div>
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">Teléfono</label>
        <Input v-model="form.phone" type="tel" placeholder="0412-1234567" />
      </div>
      <div>
        <label class="mb-1.5 block text-xs font-medium text-neutral-600">CI / RIF</label>
        <Input v-model="form.ci" type="text" placeholder="V-12345678" />
      </div>

      <div class="flex gap-3 pt-4">
        <Button type="submit">
          <Save class="size-4" />
          Guardar configuración
        </Button>
      </div>
    </form>
  </div>
</template>
