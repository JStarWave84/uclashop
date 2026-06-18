<script setup>
const sections = [
  {
    title: 'UCLA Shop',
    items: [
      { label: 'Tu tienda universitaria.', tag: 'p' },
      { label: 'Productos exclusivos para la comunidad UCLA.', tag: 'p' },
    ],
  },
  {
    title: 'Enlaces',
    links: [
      { to: '/productos', label: 'Catálogo' },
      { to: '/jornada', label: 'Jornada actual' },
    ],
  },
  {
    title: 'Pago',
    items: [
      { label: 'Pago móvil', tag: 'p' },
      { label: 'Transferencia bancaria', tag: 'p' },
    ],
  },
  {
    title: 'Contacto',
    links: [
      { to: '/contacto', label: 'Contáctanos' },
      { to: '/terminos', label: 'Términos y condiciones' },
    ],
  },
]
</script>

<template>
  <footer class="bg-ucla-900">
    <div class="ucla-ribbon" />

    <div class="mx-auto max-w-7xl px-4 pb-8 pt-12 sm:px-6 lg:px-8">
      <div class="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
        <div v-for="section in sections" :key="section.title">
          <h3 class="mb-3 text-sm font-semibold uppercase tracking-widest text-ucla-gold-light">
            {{ section.title }}
          </h3>

          <div v-if="section.items" class="space-y-2">
            <p
              v-for="item in section.items"
              :key="item.label"
              class="text-sm leading-relaxed text-ucla-200/70"
            >
              {{ item.label }}
            </p>
          </div>

          <nav v-if="section.links" class="flex flex-col gap-2">
            <router-link
              v-for="link in section.links"
              :key="link.to"
              :to="link.to"
              class="text-sm text-ucla-200/70 transition-colors hover:text-ucla-gold-light"
            >
              {{ link.label }}
            </router-link>
          </nav>
        </div>
      </div>
    </div>

    <div class="border-t border-ucla-700/50">
      <div
        class="mx-auto flex max-w-7xl flex-col items-center gap-1 px-4 py-6 sm:flex-row sm:justify-between sm:px-6 lg:px-8"
      >
        <p class="text-xs text-ucla-200/50">
          &copy; {{ new Date().getFullYear() }} UCLA Shop. Todos los derechos reservados.
        </p>
        <p class="text-xs text-ucla-200/50">Hecho para la comunidad universitaria.</p>
      </div>
    </div>
  </footer>
</template>
