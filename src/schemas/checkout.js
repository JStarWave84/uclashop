import { z } from 'zod'
import { sanitize } from '@/lib/utils'

export const checkoutSchema = z.object({
  first_name: z
    .string()
    .min(1, 'Ingresá tu nombre')
    .max(100)
    .transform((s) => sanitize(s)),
  last_name: z
    .string()
    .min(1, 'Ingresá tu apellido')
    .max(100)
    .transform((s) => sanitize(s)),
  ci: z.string().regex(/^V-\d{1,8}$/, 'Formato: V-12345678'),
  phone: z.string().regex(/^\d{4}-\d{7}$/, 'Formato: 0412-1234567'),
  email: z
    .string()
    .min(1, 'Ingresá tu correo')
    .email('Correo inválido')
    .max(200)
    .transform((s) => sanitize(s)),
  payment_reference: z.string().min(1, 'Ingresá la referencia').regex(/^\d+$/, 'Solo números'),
})

export function validateCheckout(data) {
  const result = checkoutSchema.safeParse(data)
  if (!result.success) {
    const errors = {}
    for (const issue of result.error.issues) {
      const path = issue.path.join('.')
      if (!errors[path]) errors[path] = issue.message
    }
    return { valid: false, errors, data: null }
  }
  return { valid: true, errors: {}, data: result.data }
}
