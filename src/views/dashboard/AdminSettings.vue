<script setup>
import { useAuthStore } from '@/stores/auth'
import ChangePasswordForm from '@/components/dashboard/ChangePasswordForm.vue'
import { Mail } from '@lucide/vue'

const auth = useAuthStore()
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <div>
      <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
        Ajustes
      </h1>
      <p class="mt-1 text-sm text-neutral-500">Configuración de tu cuenta de administración.</p>
    </div>

    <div class="mt-8 flex items-center gap-3 rounded-xl border border-neutral-200 bg-white p-6">
      <div class="flex size-10 items-center justify-center rounded-lg bg-ucla-50 text-ucla-600">
        <Mail class="size-5" />
      </div>
      <div class="min-w-0">
        <p class="text-xs text-neutral-400">Correo de la cuenta</p>
        <p class="truncate text-sm font-medium text-neutral-900">{{ auth.userEmail }}</p>
      </div>
    </div>

    <ChangePasswordForm class="mt-6" />
  </div>
</template>