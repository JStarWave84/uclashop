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

  // ── Admin dashboard (DashboardLayout parent) ──
  {
    path: '/admin',
    component: DashboardLayout,
    meta: { requiresAuth: true },
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
        path: 'entregas',
        name: 'admin-deliveries',
        component: () => import('@/views/dashboard/DeliveriesList.vue'),
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
        path: 'configuracion-pago',
        name: 'admin-payment-settings',
        component: () => import('@/views/dashboard/PaymentSettingsView.vue'),
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

router.beforeEach(async (to, from, next) => {
  const { useAuthStore } = await import('@/stores/auth')
  const auth = useAuthStore()

  if (auth.loading) {
    await auth.fetchSession()
  }

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    next({ name: 'admin-login' })
  } else if (to.meta.guest && auth.isAuthenticated) {
    next({ name: 'dashboard' })
  } else {
    next()
  }
})

export default router
