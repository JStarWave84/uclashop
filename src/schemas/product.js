import { z } from 'zod'
import { sanitize } from '@/lib/utils'

export const variantSchema = z.object({
  id: z.string().uuid().nullish(),
  attributes: z
    .record(z.string().trim().min(1, 'El atributo es obligatorio').max(50, 'Máximo 50 caracteres'), z
      .string()
      .trim()
      .min(1, 'El valor es obligatorio')
      .max(100, 'El valor no puede superar los 100 caracteres'))
    .refine((attrs) => Object.keys(attrs).length > 0, {
      message: 'La variante debe tener al menos un atributo',
    }),
  price: z.union([z.literal(''), z.null(), z.coerce.number().min(0, 'El precio no puede ser negativo')]).optional(),
  stock: z.coerce.number().int('El stock debe ser un número entero').min(0, 'El stock no puede ser negativo'),
  is_active: z.boolean().optional().default(true),
})

export const productSchema = z.object({
  name: z
    .string()
    .min(1, 'El nombre es obligatorio')
    .max(200, 'El nombre no puede superar los 200 caracteres')
    .transform((s) => sanitize(s)),
  description: z
    .string()
    .max(2000, 'La descripción no puede superar los 2000 caracteres')
    .optional()
    .default('')
    .transform((s) => sanitize(s ?? '')),
  price: z.coerce.number().positive('El precio debe ser mayor a 0'),
  stock: z.coerce.number().int('El stock debe ser un número entero').min(0, 'El stock no puede ser negativo'),
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

export function validateVariants(variants) {
  const errors = {}
  variants.forEach((variant, index) => {
    const result = variantSchema.safeParse(variant)
    if (!result.success) {
      for (const issue of result.error.issues) {
        if (!errors[index]) errors[index] = {}
        const field = issue.path[0] || '_'
        if (!errors[index][field]) errors[index][field] = issue.message
      }
    }
  })

  // Duplicate attribute combos within the same product
  const seen = new Map()
  variants.forEach((variant, index) => {
    const key = JSON.stringify(
      Object.entries(variant.attributes || {})
        .filter(([, v]) => String(v ?? '').trim() !== '')
        .sort(([a], [b]) => a.localeCompare(b))
    )
    if (seen.has(key)) {
      if (!errors[index]) errors[index] = {}
      if (!errors[index].attributes) errors[index].attributes = 'Combinación duplicada'
    } else {
      seen.set(key, index)
    }
  })

  return { valid: Object.keys(errors).length === 0, errors }
}

