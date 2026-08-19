<script setup>
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import {
  LayoutDashboard,
  Package,
  Calendar,
  Receipt,
  CreditCard,
  Store,
  Settings,
  Users,
  ChevronLeft,
  X,
} from '@lucide/vue'
import { useAuthStore } from '@/stores/auth'

const props = defineProps({
  mobile: { type: Boolean, default: false },
})
const emit = defineEmits(['close'])

const route = useRoute()
const auth = useAuthStore()
const collapsed = ref(false)

const adminLinks = [
  { to: '/admin', icon: LayoutDashboard, label: 'Inicio', exact: true },
  { to: '/admin/productos', icon: Package, label: 'Productos' },
  { to: '/admin/jornadas', icon: Calendar, label: 'Jornadas' },
  { to: '/admin/ordenes', icon: Receipt, label: 'Órdenes' },
  { to: '/admin/cuentas-pago', icon: CreditCard, label: 'Cuentas de pago' },
  { to: '/admin/tiendas', icon: Store, label: 'Tiendas' },
  { to: '/admin/usuarios', icon: Users, label: 'Usuarios' },
]

const storeLinks = [
  { to: '/tienda', icon: LayoutDashboard, label: 'Inicio', exact: true },
  { to: '/tienda/productos', icon: Package, label: 'Mis productos' },
  { to: '/tienda/ajustes', icon: Settings, label: 'Ajustes' },
  { to: '/tienda/miembros', icon: Users, label: 'Miembros' },
]

const adminNav = computed(() => (auth.isAdmin ? adminLinks : []))
const storeNav = computed(() => {
  if (auth.isAdmin && auth.store) return storeLinks
  return auth.isAdmin ? [] : storeLinks
})
const isAdminWithStore = computed(() => auth.isAdmin && !!auth.store)
const brand = computed(() => (auth.isAdmin ? 'Admin' : 'Tienda'))
const home = computed(() => (auth.isAdmin ? '/admin' : '/tienda'))
const backLabel = computed(() => (auth.isAdmin ? 'Volver a la tienda' : 'Ver mi tienda pública'))

function isActive(link) {
  if (link.exact) return route.path === link.to
  return route.path.startsWith(link.to)
}

function itemPadding() {
  return props.mobile ? 'min-h-12 px-4 py-3' : 'px-3 py-2.5'
}

function itemClass(link) {
  return isActive(link)
    ? 'bg-white/10 text-white'
    : 'text-ucla-200/60 hover:bg-ucla-700/40 hover:text-ucla-200'
}

function iconClass() {
  return props.mobile ? 'size-5' : 'size-4'
}
</script>

<template>
  <aside
    class="flex h-full flex-col bg-ucla-900 transition-[width] duration-300"
    :class="props.mobile ? 'w-full' : collapsed ? 'w-16' : 'w-60'"
  >
    <div class="flex h-14 shrink-0 items-center gap-2 border-b border-ucla-700/50 px-4">
      <router-link
        :to="home"
        class="flex min-w-0 flex-1 items-center gap-2.5"
        @click="props.mobile && emit('close')"
      >
        <span
          class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-ucla-gold font-bold text-ucla-900 shadow-sm"
          style="font-family: var(--font-display)"
        >
          U
        </span>
        <span
          v-show="!collapsed"
          class="truncate text-sm font-medium uppercase tracking-widest text-ucla-gold-light"
        >
          {{ brand }}
        </span>
      </router-link>

      <button
        v-if="!props.mobile"
        class="ml-auto shrink-0 text-ucla-200/50 transition-colors hover:text-white"
        @click="collapsed = !collapsed"
        :aria-label="collapsed ? 'Expandir sidebar' : 'Colapsar sidebar'"
      >
        <ChevronLeft class="size-4 transition-transform" :class="{ 'rotate-180': collapsed }" />
      </button>

      <button
        v-else
        class="flex size-11 shrink-0 items-center justify-center rounded-lg text-ucla-200/70 transition-colors hover:bg-white/10 hover:text-white"
        @click="emit('close')"
        aria-label="Cerrar menú"
      >
        <X class="size-5" />
      </button>
    </div>

    <nav class="flex-1 overflow-y-auto p-3">
      <router-link
        v-for="link in adminNav"
        :key="link.to"
        :to="link.to"
        class="relative flex items-center gap-3 rounded-lg font-medium transition-colors"
        :class="[itemPadding(), itemClass(link)]"
        @click="props.mobile && emit('close')"
      >
        <span
          v-if="isActive(link)"
          class="absolute inset-y-2 left-0 w-1 rounded-r-full bg-ucla-gold"
          aria-hidden="true"
        />
        <component
          :is="link.icon"
          class="shrink-0 transition-colors"
          :class="[iconClass(), isActive(link) ? 'text-ucla-gold-light' : '']"
          aria-hidden="true"
        />
        <span v-show="!collapsed" class="truncate">{{ link.label }}</span>
      </router-link>

      <p
        v-if="isAdminWithStore"
        v-show="!collapsed"
        class="px-3 pb-1 pt-5 text-[11px] font-semibold uppercase tracking-widest text-ucla-200/40"
      >
        Mi tienda
      </p>

      <router-link
        v-for="link in storeNav"
        :key="link.to"
        :to="link.to"
        class="relative flex items-center gap-3 rounded-lg font-medium transition-colors"
        :class="[itemPadding(), itemClass(link)]"
        @click="props.mobile && emit('close')"
      >
        <span
          v-if="isActive(link)"
          class="absolute inset-y-2 left-0 w-1 rounded-r-full bg-ucla-gold"
          aria-hidden="true"
        />
        <component
          :is="link.icon"
          class="shrink-0 transition-colors"
          :class="[iconClass(), isActive(link) ? 'text-ucla-gold-light' : '']"
          aria-hidden="true"
        />
        <span v-show="!collapsed" class="truncate">{{ link.label }}</span>
      </router-link>
    </nav>

    <div class="border-t border-ucla-700/50 p-3">
      <router-link
        :to="home"
        class="flex items-center gap-3 rounded-lg text-xs font-medium text-ucla-200/40 transition-colors hover:text-ucla-200"
        :class="props.mobile ? 'min-h-11 py-3' : 'py-2.5'"
        @click="props.mobile && emit('close')"
      >
        <ChevronLeft class="size-3.5 shrink-0" />
        <span v-show="!collapsed">{{ backLabel }}</span>
      </router-link>
    </div>
  </aside>
</template>
