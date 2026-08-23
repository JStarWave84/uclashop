<script setup>
import { Button } from '@/components/ui/button'
import { useHead } from '@unhead/vue'
import { RouterLink } from 'vue-router'
import { ArrowLeft, Store } from '@lucide/vue'

useHead({
  title: 'Página no encontrada',
})
</script>

<template>
  <div class="mx-auto flex max-w-2xl flex-col items-center px-4 py-24 text-center sm:py-32">
    <span
      class="bg-gradient-to-br from-ucla-700 to-ucla-400 bg-clip-text text-7xl font-bold tracking-tight text-transparent sm:text-8xl"
      style="font-family: var(--font-display)"
    >
      404
    </span>

    <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ucla-900 sm:text-3xl">
      Página no encontrada
    </h1>

    <p class="mt-3 max-w-md text-sm leading-relaxed text-ucla-900/50">
      La página que buscás no existe o fue movida. Explorá el catálogo o volvé al inicio para seguir
      descubriendo productos de la comunidad UCLA.
    </p>

    <div class="mt-8 flex w-full flex-col justify-center gap-3 sm:w-auto sm:flex-row">
      <Button size="lg" :as="RouterLink" to="/">
        <ArrowLeft class="size-4" />
        Volver al inicio
      </Button>
      <Button size="lg" variant="outline" :as="RouterLink" to="/productos">
        <Store class="size-4" />
        Explorar productos
      </Button>
    </div>
  </div>
</template>
