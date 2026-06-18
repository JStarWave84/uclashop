import { z } from 'zod'
import { sanitize } from '@/lib/utils'

export const productSchema = z.object({
  name: z
    .string()
    .min(1, 'El nombre es obligatorio')
    .max(200)
    .transform((s) => sanitize(s)),
  description: z
    .string()
    .max(2000)
    .optional()
    .default('')
    .transform((s) => sanitize(s ?? '')),
  price: z.coerce.number().positive('El precio debe ser positivo'),
  stock: z.coerce.number().int().min(0, 'El stock no puede ser negativo'),
  allow_backorder: z.boolean().optional().default(false),
  is_active: z.boolean().optional().default(true),
})

export function validateProduct(data) {
  const result = productSchema.safeParse(data)
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
