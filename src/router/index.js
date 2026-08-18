import { createRouter, createWebHistory } from 'vue-router'
import AppLayout from '@/components/site/AppLayout.vue'
import DashboardLayout from '@/components/site/DashboardLayout.vue'
import HomeView from '@/views/shop/HomeView.vue'

const routes = [
  // ── Admin login (standalone, no layout) ──
  {
    path: '/admin/login',
    name: 'admin-login',
    meta: { guest: true },
    component: () => import('@/views/dashboard/LoginView.vue'),
  },

  // ── Store login / registration (standalone, no layout) ──
  {
    path: '/tienda/login',
    name: 'store-login',
    meta: { guest: true },
    component: () => import('@/views/dashboard/LoginView.vue'),
  },
  {
    path: '/registro-tienda',
    name: 'store-register',
    meta: { guest: true },
    component: () => import('@/views/auth/StoreRegisterView.vue'),
  },

  // ── Admin dashboard (DashboardLayout parent, admin only) ──
  {
    path: '/admin',
    component: DashboardLayout,
    meta: { requiresAuth: true, requiresRole: 'admin' },
    children: [
      {
        path: '',
        name: 'dashboard',
        component: () => import('@/views/dashboard/DashboardHome.vue'),
      },
      {
        path: 'productos',
        name: 'admin-products',
        component: () => import('@/views/dashboard/ProductsList.vue'),
      },
      {
        path: 'productos/nuevo',
        redirect: '/admin/productos',
      },
      {
        path: 'productos/:id/editar',
        redirect: '/admin/productos',
      },
      {
        path: 'jornadas',
        name: 'admin-sessions',
        component: () => import('@/views/dashboard/SessionsList.vue'),
      },
      {
        path: 'jornadas/nueva',
        redirect: '/admin/jornadas',
      },
      {
        path: 'jornadas/:id/editar',
        redirect: '/admin/jornadas',
      },
      {
        path: 'ordenes',
        name: 'admin-orders',
        component: () => import('@/views/dashboard/OrdersList.vue'),
      },
      {
        path: 'ordenes/:id',
        name: 'admin-order-detail',
        component: () => import('@/views/dashboard/OrderDetail.vue'),
      },
      {
        path: 'cuentas-pago',
        name: 'admin-payment-accounts',
        component: () => import('@/views/dashboard/PaymentAccountsList.vue'),
      },
      {
        path: 'cuentas-pago/nueva',
        redirect: '/admin/cuentas-pago',
      },
      {
        path: 'cuentas-pago/:id/editar',
        redirect: '/admin/cuentas-pago',
      },
      {
        path: 'tiendas',
        name: 'admin-stores',
        component: () => import('@/views/dashboard/StoresList.vue'),
      },
      {
        path: 'usuarios',
        name: 'admin-users',
        component: () => import('@/views/dashboard/AdminUsers.vue'),
      },
    ],
  },

  // ── Store dashboard (DashboardLayout parent, store users only) ──
  {
    path: '/tienda',
    component: DashboardLayout,
    meta: { requiresAuth: true, requiresRole: 'store' },
    children: [
      {
        path: '',
        name: 'store-dashboard',
        component: () => import('@/views/store/StoreDashboardHome.vue'),
      },
      {
        path: 'productos',
        name: 'store-products',
        component: () => import('@/views/store/StoreProductsList.vue'),
      },
      {
        path: 'ajustes',
        name: 'store-settings',
        component: () => import('@/views/store/StoreSettings.vue'),
      },
      {
        path: 'miembros',
        name: 'store-members',
        component: () => import('@/views/store/StoreMembers.vue'),
      },
    ],
  },

  // ── Shop (AppLayout parent) ──
  {
    path: '/',
    component: AppLayout,
    children: [
      { path: '', name: 'home', component: HomeView },
      {
        path: 'tiendas',
        name: 'stores',
        component: () => import('@/views/shop/StoresDirectory.vue'),
      },
      {
        path: 'tiendas/:slug',
        name: 'store-page',
        component: () => import('@/views/shop/StorePage.vue'),
      },
      {
        path: 'productos',
        name: 'catalog',
        component: () => import('@/views/shop/CatalogView.vue'),
      },
      {
        path: 'productos/:id',
        name: 'product-detail',
        component: () => import('@/views/shop/ProductDetailView.vue'),
      },
      {
        path: 'jornada',
        name: 'jornada',
        component: () => import('@/views/shop/JornadaView.vue'),
      },
      {
        path: 'carrito',
        name: 'cart',
        component: () => import('@/views/shop/CartView.vue'),
      },
      {
        path: 'checkout',
        name: 'checkout',
        component: () => import('@/views/shop/CheckoutView.vue'),
      },
      {
        path: 'orden/:id/confirmacion',
        name: 'order-confirmation',
        component: () => import('@/views/shop/OrderConfirmationView.vue'),
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    }
    return { top: 0 }
  },
})

router.beforeEach(async (to, from, next) => {  const { useAuthStore } = await import('@/stores/auth')
  const auth = useAuthStore()

  if (auth.loading) {
    await auth.fetchSession()
  }

  if (to.name === 'checkout') {
    const { supabase } = await import('@/lib/supabaseClient')
    const { data } = await supabase
      .from('sales_sessions')
      .select('id')
      .eq('is_open', true)
      .limit(1)
      .maybeSingle()
    if (!data) {
      next({ name: 'home' })
      return
    }
  }

  const requiredRole = to.meta.requiresRole

  if (requiredRole) {
    if (!auth.isAuthenticated) {
      next({ name: requiredRole === 'admin' ? 'admin-login' : 'store-login' })
      return
    }
    if (requiredRole === 'admin') {
      if (auth.isAdmin) {
        next()
        return
      }
      next({ name: 'store-dashboard' })
      return
    }
    // Store dashboard: store users, and anyone that belongs to a store
    // (invited staff keep role NULL but get auth.store from their membership;
    //  admins own the Tienda de la UCLA and manage it from here too)
    if (auth.role === 'store' || !!auth.store) {
      next()
      return
    }
    next(auth.isAdmin ? { name: 'dashboard' } : { name: 'home' })
    return
  }

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    next({ name: 'admin-login' })
  } else if (to.meta.guest && auth.isAuthenticated) {
    next(auth.isAdmin ? { name: 'dashboard' } : auth.store ? { name: 'store-dashboard' } : { name: 'home' })
  } else {
    next()
  }
})

export default router