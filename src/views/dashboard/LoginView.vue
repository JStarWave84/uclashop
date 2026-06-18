<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { LogIn } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { useAuthStore } from '@/stores/auth'
import { signIn } from '@/lib/supabaseClient'

const router = useRouter()
const auth = useAuthStore()
const email = ref('')
const password = ref('')
const error = ref('')
const submitting = ref(false)

async function handleLogin() {
  error.value = ''
  submitting.value = true
  const { data, error: e } = await signIn(email.value, password.value)
  submitting.value = false
  if (e) {
    error.value = e.message || String(e)
    toast.error(error.value)
    return
  }
  await auth.fetchSession()
  toast.success('Sesión iniciada')
  router.push('/admin')
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
          UCLA <span class="text-ucla-500">Admin</span>
        </h1>
        <p class="mt-1 text-sm text-ucla-900/50">Iniciá sesión para gestionar la tienda</p>
      </div>

      <form class="rounded-xl border border-ucla-100 bg-white p-6" @submit.prevent="handleLogin">
        <div class="space-y-4">
          <div>
            <label for="login-email" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
              Correo electrónico
            </label>
            <Input id="login-email" v-model="email" type="email" placeholder="admin@uclashop.com" />
          </div>
          <div>
            <label for="login-password" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
              Contraseña
            </label>
            <Input id="login-password" v-model="password" type="password" placeholder="••••••••" />
          </div>
        </div>

        <Button type="submit" class="mt-6 w-full" :disabled="submitting">
          <LogIn class="size-4" />
          {{ submitting ? 'Ingresando...' : 'Iniciar sesión' }}
        </Button>
      </form>

      <p class="mt-6 text-center text-xs text-ucla-900/30">
        &copy; {{ new Date().getFullYear() }} UCLA Shop
      </p>
    </div>
  </div>
</template>
