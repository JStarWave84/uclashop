<script setup>
import { ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { KeyRound } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { signIn, updatePassword } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const saving = ref(false)

async function handleChangePassword() {
  if (!currentPassword.value) {
    toast.error('Ingresá tu contraseña actual')
    return
  }
  if (newPassword.value.length < 6) {
    toast.error('La contraseña debe tener al menos 6 caracteres')
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    toast.error('Las contraseñas no coinciden')
    return
  }

  saving.value = true
  try {
    const { error: verifyError } = await signIn(auth.userEmail, currentPassword.value)
    if (verifyError) {
      toast.error('La contraseña actual es incorrecta')
      return
    }

    const { error } = await updatePassword(newPassword.value)
    if (error) {
      toast.error(error.message || 'Error actualizando la contraseña')
      console.error(error)
      return
    }

    toast.success('Contraseña actualizada')
    currentPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="rounded-xl border border-neutral-200 bg-white p-6">
    <div class="flex items-center gap-2">
      <KeyRound class="size-4 text-ucla-600" />
      <h2 class="text-base font-semibold text-ucla-900">Cambiar contraseña</h2>
    </div>
    <p class="mt-1 text-sm text-neutral-500">
      Verificá tu contraseña actual antes de elegir una nueva.
    </p>

    <form class="mt-5 space-y-4" @submit.prevent="handleChangePassword">
      <div class="grid gap-2">
        <Label for="pw-current">Contraseña actual</Label>
        <Input
          id="pw-current"
          v-model="currentPassword"
          type="password"
          placeholder="••••••••"
          autocomplete="current-password"
        />
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div class="grid gap-2">
          <Label for="pw-new">Nueva contraseña</Label>
          <Input
            id="pw-new"
            v-model="newPassword"
            type="password"
            placeholder="Mínimo 6 caracteres"
            autocomplete="new-password"
          />
        </div>
        <div class="grid gap-2">
          <Label for="pw-confirm">Confirmar contraseña</Label>
          <Input
            id="pw-confirm"
            v-model="confirmPassword"
            type="password"
            placeholder="Repetí la contraseña"
            autocomplete="new-password"
          />
        </div>
      </div>

      <Button type="submit" :disabled="saving">
        {{ saving ? 'Cambiando...' : 'Cambiar contraseña' }}
      </Button>
    </form>
  </div>
</template>