<script setup>
import { ref } from 'vue'
import { Menu, X } from '@lucide/vue'
import CartDrawer from '@/components/shop/CartDrawer.vue'

const isMenuOpen = ref(false)

function closeMenu() {
  isMenuOpen.value = false
}
</script>

<template>
  <header class="sticky top-0 z-50 bg-white">
    <div class="ucla-ribbon" />

    <div class="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
      <router-link to="/" class="-m-1.5 flex items-baseline gap-1.5 p-1.5">
        <span
          class="text-2xl font-semibold leading-none tracking-tight text-ucla-700"
          style="font-family: var(--font-display)"
        >
          UCLA
        </span>
        <span class="text-sm font-medium uppercase tracking-widest text-ucla-500"> Shop </span>
      </router-link>

      <nav class="hidden items-center gap-8 md:flex">
        <router-link
          v-for="link in [
            { to: '/', label: 'Inicio' },
            { to: '/productos', label: 'Catálogo' },
            { to: '/jornada', label: 'Jornada' },
            { to: '/carrito', label: 'Carrito' },
          ]"
          :key="link.to"
          :to="link.to"
          class="text-sm font-medium text-ucla-900/70 transition-colors hover:text-ucla-600"
          active-class="text-ucla-600"
        >
          {{ link.label }}
        </router-link>
      </nav>

      <div class="flex items-center gap-3">
        <CartDrawer />

        <button
          class="flex size-9 items-center justify-center rounded-lg text-ucla-700/70 transition-colors hover:bg-ucla-50 hover:text-ucla-600 md:hidden"
          @click="isMenuOpen = !isMenuOpen"
          :aria-label="isMenuOpen ? 'Cerrar menú' : 'Abrir menú'"
          :aria-expanded="isMenuOpen"
        >
          <Menu v-if="!isMenuOpen" class="size-5" />
          <X v-else class="size-5" />
        </button>
      </div>
    </div>

    <Transition name="mobile-nav">
      <nav v-if="isMenuOpen" class="border-t border-ucla-100 bg-white px-4 pb-4 pt-2 md:hidden">
        <router-link
          v-for="link in [
            { to: '/', label: 'Inicio' },
            { to: '/productos', label: 'Catálogo' },
            { to: '/jornada', label: 'Jornada' },
            { to: '/cart', label: 'Carrito' },
          ]"
          :key="link.to"
          :to="link.to"
          class="block rounded-lg px-3 py-2.5 text-sm font-medium text-ucla-900/70 transition-colors hover:bg-ucla-50 hover:text-ucla-600"
          active-class="text-ucla-600 bg-ucla-50"
          @click="closeMenu"
        >
          {{ link.label }}
        </router-link>
      </nav>
    </Transition>
  </header>
</template>

<style scoped>
.mobile-nav-enter-active,
.mobile-nav-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

.mobile-nav-enter-from,
.mobile-nav-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

@media (prefers-reduced-motion: reduce) {
  .mobile-nav-enter-active,
  .mobile-nav-leave-active {
    transition: none;
  }
}
</style>
