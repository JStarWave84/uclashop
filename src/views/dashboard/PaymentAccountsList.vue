<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Plus, Pencil, Search } from '@lucide/vue'
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

const search = ref('')
const accounts = ref([])
const dialogOpen = ref(false)
const saving = ref(false)
const editingAccount = ref(null)

const form = ref({
  name: '',
  holder_name: '',
  bank: '',
  phone: '',
  ci: '',
  account_type: 'personal',
  is_active: true,
})

onMounted(async () => {
  const { data, error } = await supabase.from('payment_accounts').select('*').order('name')
  if (error) {
    console.error('fetchPaymentAccounts', error)
    toast.error('No se pudieron cargar cuentas de pago')
    accounts.value = []
  } else accounts.value = data || []
})

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return accounts.value
  return accounts.value.filter(
    (a) =>
      String(a.name || '')
        .toLowerCase()
        .includes(q) ||
      String(a.bank || '')
        .toLowerCase()
        .includes(q) ||
      String(a.phone || '').includes(q)
  )
})

const typeLabels = {
  personal: 'Personal',
  juridica: 'Jurídica',
  institucional: 'Institucional',
}

function openNewDialog() {
  editingAccount.value = null
  form.value = {
    name: '',
    holder_name: '',
    bank: '',
    phone: '',
    ci: '',
    account_type: 'personal',
    is_active: true,
  }
  dialogOpen.value = true
}

function openEditDialog(account) {
  editingAccount.value = account
  form.value = {
    name: account.name || '',
    holder_name: account.holder_name || '',
    bank: account.bank || '',
    phone: account.phone || '',
    ci: account.ci || '',
    account_type: account.account_type || 'personal',
    is_active: account.is_active ?? true,
  }
  dialogOpen.value = true
}

async function handleSave() {
  if (!form.value.name.trim()) {
    toast.error('El nombre es requerido')
    return
  }
  saving.value = true
  try {
    if (editingAccount.value) {
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
        .eq('id', editingAccount.value.id)
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
    dialogOpen.value = false
    // refresh list
    const { data, error } = await supabase.from('payment_accounts').select('*').order('name')
    if (!error) accounts.value = data || []
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
          Cuentas de pago
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtered.length }} {{ filtered.length === 1 ? 'cuenta' : 'cuentas' }}
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
            <th class="px-4 py-3 font-medium text-neutral-500">Banco</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Teléfono</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Tipo</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Estado</th>
            <th class="px-4 py-3 font-medium text-neutral-500">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-neutral-50">
          <tr
            v-for="account in filtered"
            :key="account.id"
            class="transition-colors hover:bg-neutral-50/50"
          >
            <td class="px-4 py-3 font-medium text-neutral-900">{{ account.name }}</td>
            <td class="px-4 py-3 text-neutral-600">{{ account.bank }}</td>
            <td class="px-4 py-3 text-neutral-600">{{ account.phone }}</td>
            <td class="px-4 py-3 text-xs text-neutral-500">
              {{ typeLabels[account.account_type] || account.account_type }}
            </td>
            <td class="px-4 py-3">
              <span
                class="rounded-full px-2 py-0.5 text-[10px] font-medium"
                :class="
                  account.is_active
                    ? 'bg-emerald-50 text-emerald-600'
                    : 'bg-neutral-100 text-neutral-500'
                "
              >
                {{ account.is_active ? 'Activa' : 'Inactiva' }}
              </span>
            </td>
            <td class="px-4 py-3">
              <button
                class="rounded-md p-1.5 text-neutral-400 transition-colors hover:bg-neutral-100 hover:text-ucla-600"
                @click="openEditDialog(account)"
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
    <DialogContent class="sm:max-w-lg">
      <DialogHeader>
        <DialogTitle>{{ editingAccount ? 'Editar cuenta' : 'Nueva cuenta de pago' }}</DialogTitle>
        <DialogDescription>
          {{ editingAccount ? 'Modificá los datos de la cuenta.' : 'Completá los datos de la nueva cuenta.' }}
        </DialogDescription>
      </DialogHeader>

      <form id="account-form" @submit.prevent="handleSave" class="space-y-4">
        <div class="grid gap-2">
          <Label for="acct-name">Nombre *</Label>
          <Input id="acct-name" v-model="form.name" placeholder="Ej: Mercantil Principal" required />
        </div>

        <div class="grid gap-2">
          <Label for="acct-holder">Titular</Label>
          <Input id="acct-holder" v-model="form.holder_name" placeholder="Nombre del titular" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="grid gap-2">
            <Label for="acct-bank">Banco</Label>
            <Input id="acct-bank" v-model="form.bank" placeholder="Ej: Mercantil" />
          </div>
          <div class="grid gap-2">
            <Label for="acct-phone">Teléfono</Label>
            <Input id="acct-phone" v-model="form.phone" type="tel" placeholder="0412-1234567" />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="grid gap-2">
            <Label for="acct-ci">CI / RIF</Label>
            <Input id="acct-ci" v-model="form.ci" placeholder="V-12345678" />
          </div>
          <div class="grid gap-2">
            <Label for="acct-type">Tipo</Label>
            <select
              id="acct-type"
              v-model="form.account_type"
              class="h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm transition-colors focus:border-ring focus:ring-3 focus:ring-ring/50 focus:outline-none"
            >
              <option value="personal">Personal</option>
              <option value="juridica">Jurídica</option>
              <option value="institucional">Institucional</option>
            </select>
          </div>
        </div>

        <label class="flex items-center gap-2 text-sm">
          <input
            v-model="form.is_active"
            type="checkbox"
            class="size-4 rounded border-neutral-300 text-ucla-600 focus:ring-ucla-500"
          />
          Cuenta activa
        </label>
      </form>

      <DialogFooter>
        <Button type="submit" form="account-form" :disabled="saving">
          {{ saving ? 'Guardando...' : editingAccount ? 'Guardar cambios' : 'Crear cuenta' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
