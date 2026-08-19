<script setup>
import { ref, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { Menu, LogOut } from '@lucide/vue'
import DashboardSidebar from './DashboardSidebar.vue'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const mobileMenuOpen = ref(false)
const drawerRef = ref(null)

watch(
  () => route.fullPath,
  () => {
    mobileMenuOpen.value = false
  },
)

function onKeydown(e) {
  if (e.key === 'Escape') mobileMenuOpen.value = false
}

watch(mobileMenuOpen, (open) => {
  if (open) {
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKeydown)
    drawerRef.value?.focus()
  } else {
    document.body.style.overflow = ''
    window.removeEventListener('keydown', onKeydown)
  }
})

onBeforeUnmount(() => {
  document.body.style.overflow = ''
  window.removeEventListener('keydown', onKeydown)
})

onMounted(() => {
  if (auth.loading) auth.fetchSession()
})

async function handleLogout() {
  await auth.signOut()
  router.push(auth.isAdmin ? '/admin/login' : '/tienda/login')
}
</script>

<template>
  <div class="flex h-screen overflow-hidden bg-background">
    <DashboardSidebar class="hidden md:flex" />

    <div class="flex flex-1 flex-col overflow-hidden">
      <header class="flex h-14 shrink-0 items-center gap-3 border-b border-border bg-card px-4">
        <button
          class="flex size-10 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground md:hidden"
          @click="mobileMenuOpen = true"
          :aria-expanded="mobileMenuOpen"
          aria-controls="mobile-drawer"
          aria-label="Abrir menú"
        >
          <Menu class="size-5" />
        </button>

        <div class="flex-1" />

        <span class="min-w-0 flex-1 truncate text-right text-sm text-muted-foreground">{{
          auth.isAuthenticated ? auth.userEmail : 'No autenticado'
        }}</span>
        <button
          class="flex size-10 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-destructive"
          @click="handleLogout"
          aria-label="Cerrar sesión"
        >
          <LogOut class="size-5" />
        </button>
      </header>

      <main class="flex-1 overflow-y-auto">
        <router-view />
      </main>
    </div>

    <Teleport to="body">
      <Transition name="drawer-fade">
        <div
          v-if="mobileMenuOpen"
          class="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm md:hidden"
          @click="mobileMenuOpen = false"
        />
      </Transition>

      <Transition name="drawer-slide">
        <aside
          v-if="mobileMenuOpen"
          id="mobile-drawer"
          ref="drawerRef"
          class="fixed inset-y-0 left-0 z-50 h-full w-[300px] max-w-[85vw] shadow-2xl outline-none md:hidden"
          role="dialog"
          aria-modal="true"
          aria-label="Menú de navegación"
          tabindex="-1"
        >
          <DashboardSidebar mobile @close="mobileMenuOpen = false" />
        </aside>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.drawer-fade-enter-active,
.drawer-fade-leave-active {
  transition: opacity 200ms ease;
}
.drawer-fade-enter-from,
.drawer-fade-leave-to {
  opacity: 0;
}
.drawer-slide-enter-active,
.drawer-slide-leave-active {
  transition: transform 260ms cubic-bezier(0.32, 0.72, 0, 1);
}
.drawer-slide-enter-from,
.drawer-slide-leave-to {
  transform: translateX(-100%);
}
@media (prefers-reduced-motion: reduce) {
  .drawer-fade-enter-active,
  .drawer-fade-leave-active,
  .drawer-slide-enter-active,
  .drawer-slide-leave-active {
    transition: none;
  }
}
</style>
