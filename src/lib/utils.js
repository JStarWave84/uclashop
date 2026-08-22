import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs) {
  return twMerge(clsx(inputs))
}

export function sanitize(str) {
  return String(str)
    .replace(/<[^>]*>/g, '')
    .trim()
}

export function formatVes(price) {
  return Number(price).toLocaleString('es-VE', {
    style: 'currency',
    currency: 'VES',
  })
}

export function formatPrice(price) {
  return Number(price).toLocaleString('es-VE', {
    style: 'currency',
    currency: 'USD',
  })
}

export function formatVePhone(value) {
  const digits = String(value || '').replace(/\D/g, '').slice(0, 11)
  return digits.length > 4 ? digits.slice(0, 4) + '-' + digits.slice(4) : digits
}
