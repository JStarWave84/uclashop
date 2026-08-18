import { formatPrice } from './utils'

const FALLBACK_PHONE = '584262617824'

export function normalizeWhatsAppPhone(phone) {
  if (!phone) return null
  const digits = String(phone).replace(/\D/g, '')
  if (digits.startsWith('58')) return digits
  if (digits.startsWith('0')) return `58${digits.slice(1)}`
  return digits
}

export function storePhone(item) {
  return item?.store?.phone || item?.contact_phone || null
}

export function resolveContactPhone(items) {
  if (!items || items.length === 0) return FALLBACK_PHONE
  for (const item of items) {
    const phone = normalizeWhatsAppPhone(storePhone(item))
    if (phone) return phone
  }
  return FALLBACK_PHONE
}

export function groupCartByStore(items) {
  const groups = []
  const map = new Map()
  for (const item of items || []) {
    const storeId = item?.store?.id || item?.store_id || 'default'
    let group = map.get(storeId)
    if (!group) {
      group = {
        store: item?.store || { name: 'Tienda', slug: null, phone: null },
        storeId,
        items: [],
      }
      map.set(storeId, group)
      groups.push(group)
    }
    group.items.push(item)
  }
  return groups.map((g) => ({
    ...g,
    total: g.items.reduce((s, i) => s + (i.quantity || 0) * (i.price || 0), 0),
    phone: normalizeWhatsAppPhone(g.store?.phone) || FALLBACK_PHONE,
  }))
}

export function buildCartMessage(items, total) {
  const lines = ['¡Hola! 😊 Quiero hacer este pedido:', '']
  for (const item of items) {
    lines.push(`• ${item.name} x${item.quantity} — ${formatPrice(item.price * item.quantity)}`)
  }
  lines.push('', `Total: ${formatPrice(total)}`, '', '¿Me confirmas disponibilidad? ¡Gracias!')
  return lines.join('\n')
}

export function buildWhatsAppUrl(phone, message) {
  return `https://wa.me/${phone}?text=${encodeURIComponent(message)}`
}