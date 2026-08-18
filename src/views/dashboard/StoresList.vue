<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search, Store, ShieldCheck, ShieldOff, Eye, EyeOff } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { storeLogoUrl } from '@/lib/storage'

const stores = ref([])
const search = ref('')
const filter = ref('all')

const filters = [
  { value: 'all', label: 'Todas' },
  { value: 'pending', label: 'Pendientes' },
  { value: 'verified', label: 'Verificadas' },
  { value: 'inactive', label: 'Inactivas' },
]

async function fetchStores() {
  const { data, error } = await supabase.from('stores').select('*').order('created_at', { ascending: false })
  if (error) {
    console.error('fetchStores', error)
    toast.error('Error cargando tiendas')
    stores.value = []
    return
  }
  stores.value = data || []
}

onMounted(fetchStores)

const filtered = computed(() => {
  let result = [...stores.value]
  const q = search.value.trim().toLowerCase()
  if (q) {
    result = result.filter((s) => `${s.name} ${s.slug} ${s.phone || ''}`.toLowerCase().includes(q))
  }
  if (filter.value === 'pending') result = result.filter((s) => !s.is_verified && s.is_active)
  if (filter.value === 'verified') result = result.filter((s) => s.is_verified)
  if (filter.value === 'inactive') result = result.filter((s) => !s.is_active)
  return result
})

async function toggleVerified(store) {
  const { error } = await supabase
    .from('stores')
    .update({ is_verified: !store.is_verified })
    .eq('id', store.id)
  if (error) {
    toast.error(error.message || 'No se pudo actualizar la verificación')
    return
  }
  store.is_verified = !store.is_verified
  toast.success(store.is_verified ? 'Tienda verificada' : 'Verificación removida')
}

async function toggleActive(store) {
  const { error } = await supabase.from('stores').update({ is_active: !store.is_active }).eq('id', store.id)
  if (error) {
    toast.error(error.message || 'No se pudo actualizar el estado')
    return
  }
  store.is_active = !store.is_active
  toast.success(store.is_active ? 'Tienda activada' : 'Tienda desactivada')
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Tiendas
        </h1>
        <p class="mt-1 text-sm text-neutral-500">
          {{ filtered.length }} {{ filtered.length === 1 ? 'tienda' : 'tiendas' }}
        </p>
      </div>

      <div class="relative">
        <Search class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
        <Input v-model="search" type="search" placeholder="Buscar tienda..." class="w-48 pl-9 sm:w-64" />
      </div>
    </div>

    <div class="mt-4 flex flex-wrap gap-2">
      <button
        v-for="f in filters"
        :key="f.value"
        class="rounded-full border px-3 py-1 text-xs font-medium transition-colors"
        :class="
          filter === f.value
            ? 'border-ucla-600 bg-ucla-50 text-ucla-600'
            : 'border-neutral-200 text-neutral-500 hover:border-neutral-300'
        "
        @click="filter = f.value"
      >
        {{ f.label }}
      </button>
    </div>

    <div v-if="filtered.length === 0" class="mt-10 rounded-xl border border-neutral-200 bg-white py-14 text-center">
      <Store class="mx-auto size-8 text-neutral-300" />
      <p class="mt-3 text-sm text-neutral-500">No hay tiendas que coincidan</p>
    </div>

    <div v-else class="mt-6 space-y-3">
      <div
        v-for="store in filtered"
        :key="store.id"
        class="rounded-xl border border-neutral-200 bg-white p-4"
      >
        <div class="flex items-center gap-4">
          <div class="flex size-12 shrink-0 items-center justify-center overflow-hidden rounded-xl border border-neutral-100 bg-neutral-50">
            <img v-if="store.logo_path" :src="storeLogoUrl(store.logo_path)" :alt="store.name" class="size-full object-cover" />
            <Store v-else class="size-5 text-neutral-300" />
          </div>

          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <p class="font-medium text-neutral-900">{{ store.name }}</p>
              <span
                class="rounded-full px-2 py-0.5 text-[10px] font-medium"
                :class="
                  store.is_verified
                    ? 'bg-emerald-50 text-emerald-600'
                    : store.is_active
                      ? 'bg-amber-50 text-amber-600'
                      : 'bg-red-50 text-red-600'
                "
              >
                {{ store.is_verified ? 'Verificada' : store.is_active ? 'Pendiente' : 'Inactiva' }}
              </span>
            </div>
            <p class="mt-0.5 text-xs text-neutral-400">/tiendas/{{ store.slug }} · {{ store.phone || 'Sin teléfono' }}</p>
            <p v-if="store.description" class="mt-0.5 line-clamp-1 text-xs text-neutral-500">
              {{ store.description }}
            </p>
          </div>

          <div class="flex shrink-0 items-center gap-1">
            <Button
              size="sm"
              variant="outline"
              @click="toggleVerified(store)"
              :title="store.is_verified ? 'Quitar verificación' : 'Verificar tienda'"
            >
              <ShieldCheck v-if="store.is_verified" class="size-3.5 text-emerald-600" />
              <ShieldOff v-else class="size-3.5" />
              <span class="hidden sm:inline">{{ store.is_verified ? 'Verificada' : 'Verificar' }}</span>
            </Button>
            <Button size="sm" variant="ghost" @click="toggleActive(store)" :title="store.is_active ? 'Desactivar' : 'Activar'">
              <EyeOff v-if="store.is_active" class="size-3.5 text-neutral-400" />
              <Eye v-else class="size-3.5" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>