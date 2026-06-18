<template>
  <router-view />
  <Toaster />
</template>

<script setup lang="ts">
// Root App
</script>

<script lang="ts">
// register Toaster component globally (plugin also registers it but ensure available)
import { Toaster } from 'vue-sonner'
export default {
  components: { Toaster },
}
</script>
