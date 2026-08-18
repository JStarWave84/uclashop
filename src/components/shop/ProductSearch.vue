<script setup>
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Search } from '@lucide/vue'

defineProps({
  search: { type: String, required: true },
  sortBy: { type: String, required: true },
  resultCount: { type: Number, default: 0 },
})

const emit = defineEmits(['update:search', 'update:sortBy'])

const sortOptions = [
  { value: 'name', label: 'Nombre' },
  { value: 'price-asc', label: 'Menor precio' },
  { value: 'price-desc', label: 'Mayor precio' },
]
</script>

<template>
  <header class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
    <div>
      <h1
        class="text-3xl font-semibold tracking-tight text-ucla-900 sm:text-4xl"
        style="font-family: var(--font-display)"
      >
        Catálogo
      </h1>
      <p class="mt-1 text-sm text-ucla-900/50">
        {{ resultCount }}
        {{ resultCount === 1 ? 'producto disponible' : 'productos disponibles' }}
      </p>
    </div>

    <div class="flex items-center gap-3">
      <div class="relative">
        <Search
          class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-ucla-900/40"
        />
        <Input
          :model-value="search"
          type="search"
          placeholder="Buscar productos..."
          class="w-56 pl-9 pr-3 sm:w-64"
          @update:model-value="emit('update:search', $event)"
        />
      </div>

      <Select
        :model-value="sortBy"
        class="w-40"
        @update:model-value="emit('update:sortBy', $event)"
      >
        <SelectTrigger size="sm" class="w-full">
          <SelectValue placeholder="Ordenar por..." />
        </SelectTrigger>
        <SelectContent>
          <SelectItem v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
            {{ opt.label }}
          </SelectItem>
        </SelectContent>
      </Select>
    </div>
  </header>
</template>
