import { formatPrice } from './utils'

export { formatPrice }

// ── Shop / public mock data ──

export const products = [
  {
    id: 1,
    name: 'Franela UCLA',
    description:
      'Franela color blanco con logo bordado de la UCLA. Confeccionada en algodón premium.',
    price: 15.0,
    stock: 50,
    allow_backorder: false,
  },
  {
    id: 2,
    name: 'Gorra UCLA',
    description: 'Gorra ajustable con visera curva y logo bordado.',
    price: 12.0,
    stock: 30,
    allow_backorder: false,
  },
  {
    id: 3,
    name: 'Taza UCLA',
    description: 'Taza de cerámica blanca con logo impreso. Capacidad 350 ml.',
    price: 8.0,
    stock: 0,
    allow_backorder: true,
  },
  {
    id: 4,
    name: 'Cuaderno UCLA',
    description: 'Cuaderno tamaño carta con cubierta de diseño exclusivo. 100 hojas.',
    price: 6.5,
    stock: 100,
    allow_backorder: false,
  },
  {
    id: 5,
    name: 'Bolso UCLA',
    description: 'Bolso ecológico plegable con logo. Resistente y reutilizable.',
    price: 10.0,
    stock: 25,
    allow_backorder: false,
  },
  {
    id: 6,
    name: 'Sticker pack UCLA',
    description: 'Pack de 5 stickers con diseños variados.',
    price: 3.0,
    stock: 200,
    allow_backorder: false,
  },
]

export const currentSession = {
  name: 'Jornada de junio',
  start_date: '2026-06-15',
  end_date: '2026-06-30',
  is_open: true,
}

export const defaultPaymentAccount = {
  bank: 'Mercantil Banco',
  holder: 'UCLA Shop C.A.',
  phone: '0424-1234567',
  ci: 'V-12345678',
  account_type: 'juridica',
}

export function findProduct(id) {
  return products.find((p) => String(p.id) === String(id))
}

// ── Admin mock data ──

export const orders = [
  {
    id: 'ORD-001',
    status: 'pending_payment',
    total: 42.0,
    customer_first_name: 'María',
    customer_last_name: 'González',
    customer_phone: '0412-1234567',
    customer_email: 'maria@ejemplo.com',
    customer_ci: 'V-12345678',
    created_at: '2026-06-16T10:30:00Z',
    payment_reference: null,
    payment_receipt_url: null,
    payment_account_id: 1,
  },
  {
    id: 'ORD-002',
    status: 'paid',
    total: 27.0,
    customer_first_name: 'Carlos',
    customer_last_name: 'Méndez',
    customer_phone: '0414-7654321',
    customer_email: 'carlos@ejemplo.com',
    customer_ci: 'V-23456789',
    created_at: '2026-06-15T14:20:00Z',
    payment_reference: 'MOV-2026-001',
    payment_receipt_url: null,
    payment_account_id: 1,
  },
  {
    id: 'ORD-003',
    status: 'in_delivery',
    total: 15.0,
    customer_first_name: 'Ana',
    customer_last_name: 'Rivas',
    customer_phone: '0426-9876543',
    customer_email: 'ana@ejemplo.com',
    customer_ci: 'V-34567890',
    created_at: '2026-06-14T09:00:00Z',
    payment_reference: 'MOV-2026-002',
    payment_receipt_url: null,
    payment_account_id: 2,
  },
  {
    id: 'ORD-004',
    status: 'delivered',
    total: 24.0,
    customer_first_name: 'Pedro',
    customer_last_name: 'López',
    customer_phone: '0412-5554433',
    customer_email: 'pedro@ejemplo.com',
    customer_ci: 'V-45678901',
    created_at: '2026-06-13T16:45:00Z',
    payment_reference: 'TRF-2026-001',
    payment_receipt_url: null,
    payment_account_id: 1,
  },
  {
    id: 'ORD-005',
    status: 'rejected',
    total: 10.0,
    customer_first_name: 'Sofía',
    customer_last_name: 'Torres',
    customer_phone: '0424-1112233',
    customer_email: 'sofia@ejemplo.com',
    customer_ci: 'V-56789012',
    created_at: '2026-06-12T11:15:00Z',
    payment_reference: 'MOV-2026-003',
    payment_receipt_url: null,
    payment_account_id: 2,
  },
]

export const orderItems = {
  'ORD-001': [
    { id: 1, product_name_snapshot: 'Franela UCLA', price_snapshot: 15.0, quantity: 2 },
    { id: 2, product_name_snapshot: 'Gorra UCLA', price_snapshot: 12.0, quantity: 1 },
  ],
  'ORD-002': [
    { id: 3, product_name_snapshot: 'Taza UCLA', price_snapshot: 8.0, quantity: 1 },
    { id: 4, product_name_snapshot: 'Cuaderno UCLA', price_snapshot: 6.5, quantity: 2 },
    { id: 5, product_name_snapshot: 'Sticker pack UCLA', price_snapshot: 3.0, quantity: 2 },
  ],
  'ORD-003': [{ id: 6, product_name_snapshot: 'Franela UCLA', price_snapshot: 15.0, quantity: 1 }],
  'ORD-004': [{ id: 7, product_name_snapshot: 'Gorra UCLA', price_snapshot: 12.0, quantity: 2 }],
  'ORD-005': [
    { id: 8, product_name_snapshot: 'Sticker pack UCLA', price_snapshot: 3.0, quantity: 1 },
    { id: 9, product_name_snapshot: 'Bolso UCLA', price_snapshot: 10.0, quantity: 1 },
  ],
}

export const sessions = [
  {
    id: 1,
    name: 'Jornada de junio',
    start_date: '2026-06-15',
    end_date: '2026-06-30',
    is_open: true,
    product_ids: [1, 2, 3, 4, 5, 6],
  },
  {
    id: 2,
    name: 'Jornada de julio',
    start_date: '2026-07-01',
    end_date: '2026-07-15',
    is_open: false,
    product_ids: [1, 2, 4, 5],
  },
]

export const deliveries = [
  {
    id: 1,
    order_id: 'ORD-003',
    status: 'out_for_delivery',
    notes: 'Entregar en horario de oficina de 8am a 4pm',
    created_at: '2026-06-15T08:00:00Z',
    delivered_at: null,
  },
  {
    id: 2,
    order_id: 'ORD-004',
    status: 'delivered',
    notes: 'Entregado al cliente en recepción',
    created_at: '2026-06-14T10:00:00Z',
    delivered_at: '2026-06-16T14:30:00Z',
  },
]

export const paymentAccounts = [
  {
    id: 1,
    name: 'Mercantil Principal',
    holder_name: 'UCLA Shop C.A.',
    bank: 'Mercantil Banco',
    phone: '0424-1234567',
    ci: 'V-12345678',
    account_type: 'juridica',
    is_active: true,
  },
  {
    id: 2,
    name: 'Banesco Secundaria',
    holder_name: 'UCLA Shop C.A.',
    bank: 'Banesco',
    phone: '0412-7654321',
    ci: 'V-12345678',
    account_type: 'juridica',
    is_active: true,
  },
  {
    id: 3,
    name: 'Pago móvil Admin',
    holder_name: 'María García',
    bank: 'Mercantil Banco',
    phone: '0426-5554433',
    ci: 'V-87654321',
    account_type: 'personal',
    is_active: false,
  },
]

export const paymentSettings = {
  bank: 'Mercantil Banco',
  phone: '0424-1234567',
  ci: 'V-12345678',
}

export const statusLabels = {
  pending_payment: 'Pendiente de pago',
  paid: 'Pagada',
  in_delivery: 'En entrega',
  delivered: 'Entregada',
  rejected: 'Rechazada',
}

export const statusColors = {
  pending_payment: 'text-amber-600 bg-amber-50 border-amber-200',
  paid: 'text-sky-600 bg-sky-50 border-sky-200',
  in_delivery: 'text-blue-600 bg-blue-50 border-blue-200',
  delivered: 'text-emerald-600 bg-emerald-50 border-emerald-200',
  rejected: 'text-red-600 bg-red-50 border-red-200',
  preparing: 'text-amber-600 bg-amber-50 border-amber-200',
  out_for_delivery: 'text-blue-600 bg-blue-50 border-blue-200',
}

export const orderStats = {
  total: orders.length,
  pending_payment: orders.filter((o) => o.status === 'pending_payment').length,
  paid: orders.filter((o) => o.status === 'paid').length,
  in_delivery: orders.filter((o) => o.status === 'in_delivery').length,
  delivered: orders.filter((o) => o.status === 'delivered').length,
  rejected: orders.filter((o) => o.status === 'rejected').length,
}
