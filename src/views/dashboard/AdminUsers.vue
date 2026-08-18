<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import { Users, UserPlus, Store, Trash2, Pencil, ShieldCheck, Shield, Mail, User, KeyRound, DoorOpen } from '@lucide/vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'

const users = ref([])
const stores = ref([])
const loading = ref(true)
const creating = ref(false)
const assigning = ref(false)
const editing = ref(false)
const assignDialogOpen = ref(false)
const editDialogOpen = ref(false)
const userToAssign = ref(null)
const assignStoreId = ref('')
const assignRole = ref('staff')
const editingUser = ref(null)
const editForm = ref({
  full_name: '',
  email: '',
  password: '',
  role: 'none',
})

const roleOptions = [
  { value: 'staff', label: 'Staff' },
  { value: 'owner', label: 'Dueño' },
]

const profileRoleOptions = [
  { value: 'none', label: 'Sin rol' },
  { value: 'store', label: 'Tienda' },
  { value: 'admin', label: 'Admin' },
]

const form = ref({
  full_name: '',
  email: '',
  password: '',
  store_id: '',
  role_in_store: 'staff',
})

const storeOptions = computed(() => stores.value.map((s) => ({ value: s.id, label: s.name })))

async function fetchUsers() {
  loading.value = true
  const { data, error } = await supabase.rpc('admin_list_users')
  loading.value = false
  if (error) {
    console.error('adminListUsers', error)
    toast.error(error.message || 'No se pudieron cargar los usuarios')
    users.value = []
    return
  }
  users.value = data || []
}

async function fetchStores() {
  const { data, error } = await supabase.from('stores').select('id, name, slug').order('name')
  if (error) {
    console.error('fetchStores', error)
    stores.value = []
    return
  }
  stores.value = data || []
}

onMounted(() => {
  fetchUsers()
  fetchStores()
})

async function createUser() {
  const email = form.value.email.trim()
  const password = form.value.password
  if (!email) return toast.error('El correo es obligatorio')
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return toast.error('Ingresá un correo válido')
  if (!password || password.length < 6) return toast.error('La contraseña debe tener al menos 6 caracteres')

  creating.value = true
  const { data, error } = await supabase.functions.invoke('admin-create-user', {
    body: {
      email,
      password,
      full_name: form.value.full_name.trim() || null,
      store_id: form.value.store_id || null,
      role_in_store: form.value.role_in_store,
    },
  })
  creating.value = false

  if (error) {
    toast.error(error.context?.error || error.message || 'No se pudo crear el usuario')
    return
  }
  toast.success('Usuario creado')
  form.value = { full_name: '', email: '', password: '', store_id: '', role_in_store: 'staff' }
  await fetchUsers()
}

function openAssign(user) {
  userToAssign.value = user
  assignStoreId.value = ''
  assignRole.value = 'staff'
  assignDialogOpen.value = true
}

async function assignUser() {
  if (!userToAssign.value) return
  if (!assignStoreId.value) return toast.error('Seleccioná una tienda')
  assigning.value = true
  const { error } = await supabase.rpc('admin_add_store_member', {
    p_user_id: userToAssign.value.user_id,
    p_store_id: assignStoreId.value,
    p_role_in_store: assignRole.value,
  })
  assigning.value = false
  if (error) {
    toast.error(error.message || 'No se pudo asignar a la tienda')
    return
  }
  toast.success('Usuario asignado a la tienda')
  assignDialogOpen.value = false
  await fetchUsers()
}

async function removeFromStore(user) {
  const { error } = await supabase.rpc('admin_remove_store_member', { p_user_id: user.user_id })
  if (error) {
    toast.error(error.message || 'No se pudo remover de la tienda')
    return
  }
  toast.success('Usuario removido de la tienda')
  await fetchUsers()
}

function openEdit(user) {
  editingUser.value = user
  editForm.value = {
    full_name: user.full_name || '',
    email: user.email || '',
    password: '',
    role: user.role || 'none',
  }
  editDialogOpen.value = true
}

async function saveEdit() {
  if (!editingUser.value) return
  if (!editForm.value.email) return toast.error('El correo es obligatorio')
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(editForm.value.email))
    return toast.error('Ingresá un correo válido')
  if (editForm.value.password && editForm.value.password.length < 6)
    return toast.error('La contraseña debe tener al menos 6 caracteres')

  const body = { user_id: editingUser.value.user_id }
  if (editForm.value.full_name !== (editingUser.value.full_name || ''))
    body.full_name = editForm.value.full_name
  if (editForm.value.email !== editingUser.value.email) body.email = editForm.value.email
  if (editForm.value.password) body.password = editForm.value.password
  if ((editForm.value.role || 'none') !== (editingUser.value.role || 'none'))
    body.role = editForm.value.role === 'none' ? null : editForm.value.role

  editing.value = true
  const { error } = await supabase.functions.invoke('admin-update-user', { body })
  editing.value = false

  if (error) {
    toast.error(error.context?.error || error.message || 'No se pudo actualizar el usuario')
    return
  }
  toast.success('Usuario actualizado')
  editDialogOpen.value = false
  await fetchUsers()
}

async function deleteUser(user) {
  const { error } = await supabase.functions.invoke('admin-delete-user', {
    body: { user_id: user.user_id }
  })
  if (error) {
    toast.error(error.message || 'No se pudo eliminar el usuario')
    return
  }
  toast.success('Usuario eliminado')
  await fetchUsers()
}
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <div>
      <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
        Usuarios
      </h1>
      <p class="mt-1 text-sm text-neutral-500">
        Creá cuentas y asignalas a cualquier tienda, incluida la propia.
      </p>
    </div>

    <div class="mt-6 rounded-xl border border-neutral-200 bg-white p-5">
      <h2 class="flex items-center gap-2 text-sm font-medium text-neutral-900">
        <UserPlus class="size-4 text-ucla-600" />
        Crear usuario
      </h2>

      <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div>
          <Label for="user-name">Nombre</Label>
          <div class="relative mt-1.5">
            <User class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
            <Input id="user-name" v-model="form.full_name" placeholder="Nombre completo" class="pl-9" />
          </div>
        </div>

        <div>
          <Label for="user-email">Correo *</Label>
          <div class="relative mt-1.5">
            <Mail class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
            <Input id="user-email" v-model="form.email" type="email" placeholder="correo@ejemplo.com" class="pl-9" />
          </div>
        </div>

        <div>
          <Label for="user-password">Contraseña *</Label>
          <div class="relative mt-1.5">
            <KeyRound class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
            <Input id="user-password" v-model="form.password" type="password" placeholder="Mínimo 6 caracteres" class="pl-9" />
          </div>
        </div>

        <div>
          <Label>Tienda</Label>
          <Select v-model="form.store_id">
            <SelectTrigger class="mt-1.5 w-full">
              <SelectValue placeholder="Seleccionar tienda (opcional)" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="opt in storeOptions" :key="opt.value" :value="opt.value">
                {{ opt.label }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div>
          <Label>Rol en la tienda</Label>
          <Select v-model="form.role_in_store">
            <SelectTrigger class="mt-1.5 w-full">
              <SelectValue placeholder="Rol" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="opt in roleOptions" :key="opt.value" :value="opt.value">
                {{ opt.label }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div class="flex items-end">
          <Button :disabled="creating" class="w-full" @click="createUser">
            {{ creating ? 'Creando...' : 'Crear usuario' }}
          </Button>
        </div>
      </div>
    </div>

    <div class="mt-6">
      <p class="text-sm text-neutral-500">{{ users.length }} {{ users.length === 1 ? 'usuario' : 'usuarios' }}</p>

      <div v-if="loading" class="mt-4 text-center text-sm text-neutral-400">Cargando usuarios...</div>

      <div v-else-if="users.length === 0" class="mt-4 rounded-xl border border-neutral-200 bg-white py-14 text-center">
        <Users class="mx-auto size-8 text-neutral-300" />
        <p class="mt-3 text-sm text-neutral-500">No hay usuarios todavía.</p>
      </div>

      <div v-else class="mt-4 space-y-3">
        <div
          v-for="user in users"
          :key="user.user_id"
          class="flex flex-col gap-3 rounded-xl border border-neutral-200 bg-white p-4 sm:flex-row sm:items-center"
        >
          <div class="flex min-w-0 flex-1 items-center gap-3">
            <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-ucla-50 font-medium text-ucla-600">
              {{ (user.full_name || user.email || '?').charAt(0).toUpperCase() }}
            </div>
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-neutral-900">{{ user.full_name || user.email }}</p>
              <p class="truncate text-xs text-neutral-400">{{ user.email }}</p>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <span
              class="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[10px] font-medium capitalize"
              :class="user.role === 'admin' ? 'bg-ucla-50 text-ucla-600' : user.role === 'store' ? 'bg-emerald-50 text-emerald-600' : 'bg-neutral-100 text-neutral-500'"
            >
              {{ user.role || 'Sin rol' }}
            </span>

            <span
              v-if="user.store_name"
              class="inline-flex items-center gap-1 rounded-full bg-ucla-50 px-2.5 py-0.5 text-[10px] font-medium text-ucla-600"
            >
              <Store class="size-3" />
              {{ user.store_name }}
              <span v-if="user.role_in_store === 'owner'" class="ml-0.5 inline-flex items-center">
                <ShieldCheck class="size-3" />
                Dueño
              </span>
              <span v-else class="ml-0.5 inline-flex items-center">
                <Shield class="size-3" />
                Staff
              </span>
            </span>

            <div class="flex items-center gap-1">
              <Button size="sm" variant="outline" @click="openEdit(user)">
                <Pencil class="size-3.5" />
              </Button>
              <Button v-if="!user.store_name && user.role !== 'admin'" size="sm" variant="outline" @click="openAssign(user)">
                <Store class="size-3.5" />
                Agregar a tienda
              </Button>
              <Button
                size="sm"
                variant="ghost"
                class="text-neutral-400 hover:text-red-500"
                @click="deleteUser(user)"
              >
                <Trash2 class="size-3.5" />
              </Button>
              <Button
                v-if="user.store_name && user.role !== 'admin'"
                size="sm"
                variant="ghost"
                class="text-neutral-400 hover:text-red-500"
                @click="removeFromStore(user)"
              >
                <DoorOpen class="size-3.5" />
                Remover de tienda
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <Dialog v-model:open="assignDialogOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Asignar a tienda</DialogTitle>
          <DialogDescription>
            Agregar a {{ userToAssign?.email }} a una tienda.
          </DialogDescription>
        </DialogHeader>

        <div class="space-y-4">
          <div>
            <Label>Tienda *</Label>
            <Select v-model="assignStoreId">
              <SelectTrigger class="mt-1.5 w-full">
                <SelectValue placeholder="Seleccionar tienda..." />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="opt in storeOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div>
            <Label>Rol</Label>
            <Select v-model="assignRole">
              <SelectTrigger class="mt-1.5 w-full">
                <SelectValue placeholder="Rol" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="opt in roleOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          <DialogFooter>
            <Button variant="outline" @click="assignDialogOpen = false">Cancelar</Button>
            <Button :disabled="assigning" @click="assignUser">
              {{ assigning ? 'Asignando...' : 'Asignar' }}
            </Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="editDialogOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Editar usuario</DialogTitle>
          <DialogDescription>
            Actualizar {{ editingUser?.email }}.
          </DialogDescription>
        </DialogHeader>

        <div class="space-y-4">
          <div>
            <Label for="edit-name">Nombre</Label>
            <div class="relative mt-1.5">
              <User class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
              <Input id="edit-name" v-model="editForm.full_name" placeholder="Nombre completo" class="pl-9" />
            </div>
          </div>

          <div>
            <Label for="edit-email">Correo *</Label>
            <div class="relative mt-1.5">
              <Mail class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
              <Input id="edit-email" v-model="editForm.email" type="email" class="pl-9" />
            </div>
          </div>

          <div>
            <Label for="edit-password">Contraseña</Label>
            <div class="relative mt-1.5">
              <KeyRound class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-400" />
              <Input id="edit-password" v-model="editForm.password" type="password" placeholder="Nueva contraseña (opcional)" class="pl-9" />
            </div>
          </div>

          <div>
            <Label>Rol</Label>
            <Select v-model="editForm.role">
              <SelectTrigger class="mt-1.5 w-full">
                <SelectValue placeholder="Rol" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem v-for="opt in profileRoleOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          <DialogFooter>
            <Button variant="outline" @click="editDialogOpen = false">Cancelar</Button>
            <Button :disabled="editing" @click="saveEdit">
              {{ editing ? 'Guardando...' : 'Guardar' }}
            </Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>
  </div>
</template>