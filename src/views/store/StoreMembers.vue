<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Users, UserPlus, Trash2, ShieldCheck, Shield } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const members = ref([])
const loading = ref(true)
const inviteEmail = ref('')
const inviting = ref(false)

const currentUserRole = computed(() => {
  const me = members.value.find((m) => m.user_id === auth.user?.id)
  return me?.role_in_store || 'staff'
})

const isOwner = computed(() => currentUserRole.value === 'owner')

async function fetchMembers() {
  loading.value = true
  const { data, error } = await supabase.rpc('get_store_members')
  loading.value = false
  if (error) {
    console.error('getStoreMembers', error)
    toast.error('No se pudieron cargar los miembros')
    members.value = []
    return
  }
  members.value = data || []
}

onMounted(fetchMembers)

async function invite() {
  const email = inviteEmail.value.trim()
  if (!email) return toast.error('Ingresá un correo')
  inviting.value = true
  const { error } = await supabase.rpc('add_store_member', { p_email: email })
  inviting.value = false
  if (error) {
    toast.error(error.message || 'No se pudo invitar')
    return
  }
  toast.success('Miembro agregado')
  inviteEmail.value = ''
  await fetchMembers()
}

async function removeMember(userId) {
  const { error } = await supabase.rpc('remove_store_member', { p_user_id: userId })
  if (error) {
    toast.error(error.message || 'No se pudo remover')
    return
  }
  toast.success('Miembro removido')
  await fetchMembers()
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <div>
      <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
        Miembros de la tienda
      </h1>
      <p class="mt-1 text-sm text-neutral-500">
        {{ isOwner ? 'Invitá a tu equipo a administrar la tienda.' : 'Solo el dueño puede invitar o remover miembros.' }}
      </p>
    </div>

    <div v-if="isOwner" class="mt-8 flex flex-col gap-3 sm:flex-row">
      <div class="flex-1">
        <Input
          v-model="inviteEmail"
          type="email"
          placeholder="correo del miembro que ya tiene cuenta..."
        />
      </div>
      <Button :disabled="inviting" @click="invite">
        <UserPlus class="size-4" />
        {{ inviting ? 'Invitando...' : 'Invitar' }}
      </Button>
    </div>

    <div v-if="loading" class="mt-8 text-center text-sm text-neutral-400">Cargando miembros...</div>

    <div v-else class="mt-6 space-y-3">
      <div
        v-for="member in members"
        :key="member.user_id"
        class="flex items-center justify-between rounded-xl border border-neutral-200 bg-white p-4"
      >
        <div class="flex items-center gap-3">
          <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-ucla-50 font-medium text-ucla-600">
            {{ (member.full_name || member.email || '?').charAt(0).toUpperCase() }}
          </div>
          <div>
            <p class="text-sm font-medium text-neutral-900">
              {{ member.full_name || member.email }}
              <span v-if="member.user_id === auth.user?.id" class="text-xs text-neutral-400">(vos)</span>
            </p>
            <p class="text-xs text-neutral-400">{{ member.email }}</p>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <span
            class="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[10px] font-medium capitalize"
            :class="member.role_in_store === 'owner' ? 'bg-ucla-50 text-ucla-600' : 'bg-neutral-100 text-neutral-500'"
          >
            <ShieldCheck v-if="member.role_in_store === 'owner'" class="size-3" />
            <Shield v-else class="size-3" />
            {{ member.role_in_store === 'owner' ? 'Dueño' : 'Staff' }}
          </span>

          <Button
            v-if="isOwner && member.user_id !== auth.user?.id"
            variant="ghost"
            size="sm"
            class="text-neutral-400 hover:text-red-500"
            @click="removeMember(member.user_id)"
          >
            <Trash2 class="size-3.5" />
          </Button>
        </div>
      </div>

      <div v-if="members.length === 0" class="py-12 text-center text-sm text-neutral-400">
        <Users class="mx-auto size-8 text-neutral-300" />
        <p class="mt-2">No hay miembros todavía.</p>
      </div>
    </div>
  </div>
</template>