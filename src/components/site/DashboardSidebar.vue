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
} from '@lucide/vue'
import { useAuthStore } from '@/stores/auth'

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
</script>

<template>
  <aside
    class="flex flex-col bg-ucla-900 transition-all duration-300"
    :class="collapsed ? 'w-16' : 'w-60'"
  >
    <div class="flex h-14 items-center border-b border-ucla-700/50 px-3">
      <router-link :to="home" class="flex items-center gap-2 overflow-hidden">
        <span
          class="shrink-0 text-lg font-semibold tracking-tight text-white"
          style="font-family: var(--font-display)"
        >
          U
        </span>
        <span
          v-show="!collapsed"
          class="text-sm font-medium uppercase tracking-widest text-ucla-gold-light"
        >
          {{ brand }}
        </span>
      </router-link>

      <button
        class="ml-auto shrink-0 text-ucla-200/50 transition-colors hover:text-white"
        @click="collapsed = !collapsed"
        :aria-label="collapsed ? 'Expandir sidebar' : 'Colapsar sidebar'"
      >
        <ChevronLeft class="size-4 transition-transform" :class="{ 'rotate-180': collapsed }" />
      </button>
    </div>

    <nav class="flex-1 overflow-y-auto p-2">
      <router-link
        v-for="link in adminNav"
        :key="link.to"
        :to="link.to"
        class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors"
        :class="
          isActive(link)
            ? 'bg-ucla-700/60 text-ucla-gold-light'
            : 'text-ucla-200/60 hover:bg-ucla-700/40 hover:text-ucla-200'
        "
      >
        <component :is="link.icon" class="size-4 shrink-0" />
        <span v-show="!collapsed" class="truncate">{{ link.label }}</span>
      </router-link>

      <p
        v-if="isAdminWithStore"
        v-show="!collapsed"
        class="px-3 pb-1 pt-4 text-[11px] font-semibold uppercase tracking-wider text-ucla-200/40"
      >
        Mi tienda
      </p>

      <router-link
        v-for="link in storeNav"
        :key="link.to"
        :to="link.to"
        class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors"
        :class="
          isActive(link)
            ? 'bg-ucla-700/60 text-ucla-gold-light'
            : 'text-ucla-200/60 hover:bg-ucla-700/40 hover:text-ucla-200'
        "
      >
        <component :is="link.icon" class="size-4 shrink-0" />
        <span v-show="!collapsed" class="truncate">{{ link.label }}</span>
      </router-link>
    </nav>

    <div class="border-t border-ucla-700/50 p-2">
      <router-link
        :to="home"
        class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-xs font-medium text-ucla-200/40 transition-colors hover:text-ucla-200"
      >
        <ChevronLeft class="size-3.5 shrink-0" />
        <span v-show="!collapsed">{{ backLabel }}</span>
      </router-link>
    </div>
  </aside>
</template>