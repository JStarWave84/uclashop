<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Menu, LogOut } from '@lucide/vue'
import DashboardSidebar from './DashboardSidebar.vue'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()
const mobileMenuOpen = ref(false)

onMounted(() => {
  if (auth.loading) auth.fetchSession()
})

async function handleLogout() {
  await auth.signOut()
  router.push('/admin/login')
}
</script>

<template>
  <div class="flex h-screen overflow-hidden bg-background">
    <DashboardSidebar class="hidden md:flex" />

    <div class="flex flex-1 flex-col overflow-hidden">
      <header class="flex h-14 shrink-0 items-center gap-3 border-b border-border bg-card px-4">
        <button
          class="flex size-8 items-center justify-center rounded-lg text-muted-foreground hover:bg-muted hover:text-foreground md:hidden"
          @click="mobileMenuOpen = !mobileMenuOpen"
          aria-label="Abrir menú"
        >
          <Menu class="size-4" />
        </button>

        <div class="flex-1" />

        <span class="text-sm text-muted-foreground">{{
          auth.isAuthenticated ? auth.userEmail : 'No autenticado'
        }}</span>
        <button
          class="flex size-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-destructive"
          @click="handleLogout"
          aria-label="Cerrar sesión"
        >
          <LogOut class="size-4" />
        </button>
      </header>

      <main class="flex-1 overflow-y-auto">
        <router-view />
      </main>
    </div>

    <Teleport to="body">
      <div
        v-if="mobileMenuOpen"
        class="fixed inset-0 z-40 bg-black/40 md:hidden"
        @click="mobileMenuOpen = false"
      />
      <aside v-if="mobileMenuOpen" class="fixed inset-y-0 left-0 z-50 w-60 md:hidden">
        <DashboardSidebar />
        <button
          class="absolute -right-8 top-4 text-white"
          @click="mobileMenuOpen = false"
          aria-label="Cerrar menú"
        >
          ✕
        </button>
      </aside>
    </Teleport>
  </div>
</template>
