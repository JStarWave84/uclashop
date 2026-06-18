<script setup>
import { ArrowRight } from '@lucide/vue'
import { Button } from '@/components/ui/button'

const props = defineProps({
  session: { type: Object, required: true },
  productCount: { type: Number, default: 0 },
})

function formatDateRange(start, end) {
  const opts = { day: 'numeric', month: 'long', year: 'numeric' }
  const s = new Date(start).toLocaleDateString('es-ES', opts)
  const e = new Date(end).toLocaleDateString('es-ES', opts)
  return `${s} al ${e}`
}
</script>

<template>
  <section
    class="relative overflow-hidden rounded-2xl bg-gradient-to-br from-ucla-50 via-white to-ucla-50"
  >
    <div class="relative z-10 px-6 py-12 sm:px-10 sm:py-16 lg:px-14 lg:py-20">
      <span
        class="inline-block rounded-full border border-ucla-200 px-3 py-1 text-[11px] font-medium uppercase tracking-widest text-ucla-600"
      >
        Jornada activa
      </span>

      <h1
        class="mt-4 max-w-2xl text-3xl font-semibold leading-tight tracking-tight text-ucla-900 sm:text-4xl lg:text-5xl"
        style="font-family: var(--font-display)"
      >
        {{ session.name }}
      </h1>

      <p class="mt-3 text-sm text-ucla-900/60 sm:text-base">
        {{ formatDateRange(session.start_date, session.end_date) }}
      </p>

      <p class="mt-1 text-sm text-ucla-900/50">
        {{ productCount }}
        {{ productCount === 1 ? 'producto disponible' : 'productos disponibles' }}
        en esta jornada
      </p>

      <div class="mt-6 flex flex-wrap gap-3">
        <router-link to="/productos">
          <Button size="lg">
            Ver productos
            <ArrowRight class="size-4" />
          </Button>
        </router-link>
      </div>
    </div>

    <div
      class="pointer-events-none absolute -bottom-8 -right-8 select-none text-[200px] font-display font-bold leading-none text-ucla-100/40 sm:text-[280px]"
      aria-hidden="true"
    >
      UCLA
    </div>
  </section>
</template>
