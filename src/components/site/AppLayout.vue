<script setup>
import AppHeader from './AppHeader.vue'
import AppFooter from './AppFooter.vue'
</script>

<template>
  <a
    href="#main-content"
    class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:rounded-lg focus:bg-ucla-600 focus:px-4 focus:py-2 focus:text-sm focus:text-white"
  >
    Ir al contenido principal
  </a>

  <div class="flex min-h-screen flex-col">
    <AppHeader />

    <main id="main-content" class="flex-1">
      <router-view />
    </main>

    <AppFooter />
  </div>
</template>
