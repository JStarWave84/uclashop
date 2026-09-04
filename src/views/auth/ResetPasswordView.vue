<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Lock, CheckCircle, AlertCircle } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { supabase, updatePassword } from '@/lib/supabaseClient'

const router = useRouter()
const loading = ref(true)
const validToken = ref(false)
const newPassword = ref('')
const confirmPassword = ref('')
const submitting = ref(false)
const success = ref(false)

onMounted(async () => {
  const hash = window.location.hash
  if (hash) {
    const params = new URLSearchParams(hash.substring(1))
    const accessToken = params.get('access_token')
    const type = params.get('type')

    if (accessToken && type === 'recovery') {
      const { error } = await supabase.auth.setSession({
        access_token: accessToken,
        refresh_token: params.get('refresh_token') || '',
      })
      if (error) {
        console.error('Token exchange error:', error)
        validToken.value = false
      } else {
        validToken.value = true
      }
    }
  }
  loading.value = false
})

async function handleSubmit() {
  if (newPassword.value.length < 6) {
    toast.error('La contraseña debe tener al menos 6 caracteres')
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    toast.error('Las contraseñas no coinciden')
    return
  }

  submitting.value = true
  const { error } = await updatePassword(newPassword.value)
  submitting.value = false

  if (error) {
    toast.error(error.message || 'Error actualizando la contraseña')
    return
  }

  success.value = true
  toast.success('Contraseña actualizada')
  setTimeout(() => router.push('/admin/login'), 3000)
}
</script>

<template>
  <div
    class="flex min-h-screen items-center justify-center bg-gradient-to-br from-ucla-50 via-white to-ucla-50 px-4"
  >
    <div class="w-full max-w-sm">
      <div class="mb-8 text-center">
        <h1
          class="text-3xl font-semibold tracking-tight text-ucla-900"
          style="font-family: var(--font-display)"
        >
          Nueva <span class="text-ucla-500">contraseña</span>
        </h1>
        <p class="mt-1 text-sm text-ucla-900/50">Elegí una nueva contraseña para tu cuenta.</p>
      </div>

      <div class="rounded-xl border border-ucla-100 bg-white p-6">
        <div v-if="loading" class="py-8 text-center text-sm text-ucla-900/40">
          Verificando enlace...
        </div>

        <template v-else-if="!validToken">
          <div class="py-4 text-center">
            <div class="mx-auto mb-3 flex size-12 items-center justify-center rounded-full bg-red-50">
              <AlertCircle class="size-6 text-red-500" />
            </div>
            <p class="text-sm font-medium text-ucla-900">Enlace inválido o expirado</p>
            <p class="mt-1 text-sm text-ucla-900/50">
              El enlace de recuperación no es válido o ya expiró. Solicitá uno nuevo.
            </p>
          </div>
        </template>

        <template v-else-if="!success">
          <form @submit.prevent="handleSubmit">
            <div class="space-y-4">
              <div>
                <label for="new-password" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
                  Nueva contraseña
                </label>
                <Input
                  id="new-password"
                  v-model="newPassword"
                  type="password"
                  placeholder="Mínimo 6 caracteres"
                  required
                  minlength="6"
                />
              </div>
              <div>
                <label
                  for="confirm-password"
                  class="mb-1.5 block text-xs font-medium text-ucla-900/60"
                >
                  Confirmar contraseña
                </label>
                <Input
                  id="confirm-password"
                  v-model="confirmPassword"
                  type="password"
                  placeholder="Repetí la contraseña"
                  required
                  minlength="6"
                />
              </div>
            </div>

            <Button type="submit" class="mt-6 w-full" :disabled="submitting">
              <Lock class="size-4" />
              {{ submitting ? 'Guardando...' : 'Guardar nueva contraseña' }}
            </Button>
          </form>
        </template>

        <template v-else>
          <div class="py-4 text-center">
            <div class="mx-auto mb-3 flex size-12 items-center justify-center rounded-full bg-emerald-50">
              <CheckCircle class="size-6 text-emerald-500" />
            </div>
            <p class="text-sm font-medium text-ucla-900">Contraseña actualizada</p>
            <p class="mt-1 text-sm text-ucla-900/50">
              Serás redirigido al inicio de sesión en unos segundos.
            </p>
          </div>
        </template>
      </div>

      <p class="mt-6 text-center text-xs text-ucla-900/30">
        <router-link
          to="/admin/login"
          class="font-medium text-ucla-600 underline underline-offset-2 hover:text-ucla-700"
        >
          Volver al inicio de sesión
        </router-link>
      </p>
    </div>
  </div>
</template>
