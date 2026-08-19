<template>
  <router-view />
  <Toaster />
</template>

<script setup lang="ts">
import { useHead } from '@unhead/vue'

useHead({
  titleTemplate: (title) => (title ? `${title} — UCLA Shop` : 'UCLA Shop — tu tienda universitaria'),
  meta: [
    { key: 'description', name: 'description', content: 'Marketplace universitario de la UCLA: explorá las tiendas de la comunidad y descubrí sus productos.' },
    { key: 'og:type', property: 'og:type', content: 'website' },
    { key: 'og:site_name', property: 'og:site_name', content: 'UCLA Shop' },
    { key: 'og:title', property: 'og:title', content: 'UCLA Shop — tu tienda universitaria' },
    { key: 'og:description', property: 'og:description', content: 'Marketplace universitario de la UCLA: explorá las tiendas de la comunidad y descubrí sus productos.' },
    { key: 'og:image', property: 'og:image', content: '/og-default.png' },
    { key: 'twitter:card', name: 'twitter:card', content: 'summary_large_image' },
  ],
})
</script>

<script lang="ts">
// register Toaster component globally (plugin also registers it but ensure available)
import { Toaster } from 'vue-sonner'
export default {
  components: { Toaster },
}
</script>
