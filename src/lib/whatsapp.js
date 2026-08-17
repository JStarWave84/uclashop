import { formatPrice } from './utils'

const FALLBACK_PHONE = '584262617824'

export function normalizeWhatsAppPhone(phone) {
  if (!phone) return null
  const digits = String(phone).replace(/\D/g, '')
  if (digits.startsWith('58')) return digits
  if (digits.startsWith('0')) return `58${digits.slice(1)}`
  return digits
}

export function resolveContactPhone(items) {
  if (!items || items.length === 0) return FALLBACK_PHONE
  for (const item of items) {
    const phone = normalizeWhatsAppPhone(item?.contact_phone)
    if (phone) return phone
  }
  return FALLBACK_PHONE
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