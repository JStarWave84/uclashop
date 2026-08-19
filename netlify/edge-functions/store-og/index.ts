import type { Context } from 'netlify:edge'

const SUPABASE_URL = Deno.env.get('VITE_SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('VITE_SUPABASE_ANON_KEY') ?? ''

const DEFAULT_DESCRIPTION =
  'Marketplace universitario de la UCLA: explorá las tiendas de la comunidad y descubrí sus productos.'

function esc(s: string): string {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

function formatPrice(price: number): string {
  return Number(price).toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

async function fetchJson(url: string): Promise<unknown> {
  const res = await fetch(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      Accept: 'application/json',
    },
  })
  if (!res.ok) throw new Error(`Supabase ${res.status}`)
  return res.json()
}

function buildTags(og: { title: string; description: string; image: string }, url: string): string {
  return `
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="UCLA Shop" />
    <meta property="og:title" content="${esc(og.title)}" />
    <meta property="og:description" content="${esc(og.description)}" />
    <meta property="og:image" content="${esc(og.image)}" />
    <meta property="og:url" content="${esc(url)}" />
    <link rel="canonical" href="${esc(url)}" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${esc(og.title)}" />
    <meta name="twitter:description" content="${esc(og.description)}" />
    <meta name="twitter:image" content="${esc(og.image)}" />`
}

export default async (request: Request, context: Context) => {
  const { pathname, origin } = new URL(request.url)
  const pageUrl = `${origin}${pathname}`

  const storeMatch = pathname.match(/^\/tiendas\/([^/]+)\/?$/)
  const productMatch = pathname.match(/^\/productos\/([^/]+)\/?$/)

  let og: { title: string; description: string; image: string } | null = null

  try {
    if (storeMatch && SUPABASE_URL && SUPABASE_ANON_KEY) {
      const rows = (await fetchJson(
        `${SUPABASE_URL}/rest/v1/stores?select=name,description,logo_path&slug=eq.${encodeURIComponent(storeMatch[1])}&limit=1`,
      )) as Array<{ name: string; description: string | null; logo_path: string | null }>
      const store = rows[0]
      if (store) {
        og = {
          title: store.name,
          description: store.description || DEFAULT_DESCRIPTION,
          image: store.logo_path
            ? `${SUPABASE_URL}/storage/v1/object/public/store-logos/${store.logo_path}`
            : `${origin}/og-default.png`,
        }
      }
    } else if (productMatch && SUPABASE_URL && SUPABASE_ANON_KEY) {
      const rows = (await fetchJson(
        `${SUPABASE_URL}/rest/v1/products?select=name,description,price,product_image_path,stores(name)&id=eq.${productMatch[1]}&limit=1`,
      )) as Array<{
        name: string
        description: string | null
        price: number
        product_image_path: string | null
        stores: { name: string } | null
      }>
      const product = rows[0]
      if (product) {
        const storeName = product.stores?.name
        og = {
          title: product.name,
          description: storeName
            ? `${product.description || `Producto de ${storeName}`} · ${formatPrice(product.price)}`
            : product.description || `Producto a ${formatPrice(product.price)}`,
          image: product.product_image_path
            ? `${SUPABASE_URL}/storage/v1/object/public/product-images/${product.product_image_path}`
            : `${origin}/og-default.png`,
        }
      }
    }
  } catch (err) {
    console.error('store-og supabase fetch failed', err)
    og = null
  }

  const res = await context.next()
  const html = await res.text()

  if (!og) {
    return new Response(html, {
      headers: {
        ...Object.fromEntries(res.headers.entries()),
        'content-type': 'text/html; charset=utf-8',
      },
    })
  }

  const final = html.replace('</head>', `${buildTags(og, pageUrl)}\n  </head>`)

  return new Response(final, {
    headers: {
      ...Object.fromEntries(res.headers.entries()),
      'content-type': 'text/html; charset=utf-8',
    },
  })
}
