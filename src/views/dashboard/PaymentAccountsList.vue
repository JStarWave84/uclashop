<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Plus, Pencil, Search } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const router = useRouter()
const search = ref('')
const accounts = ref([])

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
        <Button as="router-link" to="/admin/cuentas-pago/nueva">
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
                @click="router.push(`/admin/cuentas-pago/${account.id}/editar`)"
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
</template>
