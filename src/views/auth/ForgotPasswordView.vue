<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { ArrowLeft, Mail } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { resetPasswordForEmail } from '@/lib/supabaseClient'

const router = useRouter()
const email = ref('')
const submitting = ref(false)
const sent = ref(false)

async function handleSubmit() {
  submitting.value = true
  const { error } = await resetPasswordForEmail(email.value)
  submitting.value = false
  if (error) {
    toast.error(error.message || 'Error enviando el correo')
    return
  }
  sent.value = true
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
          Recuperar <span class="text-ucla-500">contraseña</span>
        </h1>
        <p class="mt-1 text-sm text-ucla-900/50">
          Ingresá tu correo y te enviaremos un enlace para restablecer tu contraseña.
        </p>
      </div>

      <div class="rounded-xl border border-ucla-100 bg-white p-6">
        <template v-if="!sent">
          <form @submit.prevent="handleSubmit">
            <div>
              <label for="reset-email" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
                Correo electrónico
              </label>
              <Input
                id="reset-email"
                v-model="email"
                type="email"
                placeholder="admin@uclashop.com"
                required
              />
            </div>

            <Button type="submit" class="mt-6 w-full" :disabled="submitting">
              <Mail class="size-4" />
              {{ submitting ? 'Enviando...' : 'Enviar enlace de recuperación' }}
            </Button>
          </form>
        </template>

        <template v-else>
          <div class="py-4 text-center">
            <div class="mx-auto mb-3 flex size-12 items-center justify-center rounded-full bg-emerald-50">
              <Mail class="size-6 text-emerald-500" />
            </div>
            <p class="text-sm font-medium text-ucla-900">Correo enviado</p>
            <p class="mt-1 text-sm text-ucla-900/50">
              Revisá la bandeja de entrada de
              <strong class="text-ucla-900">{{ email }}</strong> y seguí las instrucciones para
              restablecer tu contraseña.
            </p>
          </div>
        </template>
      </div>

      <p class="mt-6 text-center text-xs text-ucla-900/30">
        <router-link
          to="/admin/login"
          class="inline-flex items-center gap-1 font-medium text-ucla-600 underline"
        >
          <ArrowLeft class="size-3" />
          Volver al inicio de sesión
        </router-link>
      </p>
    </div>
  </div>
</template>
