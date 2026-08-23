const SUPABASE_URL = Deno.env.get('VITE_SUPABASE_URL') ?? ''
const SUPABASE_ANON_KEY = Deno.env.get('VITE_SUPABASE_ANON_KEY') ?? ''

function esc(s: string): string {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
}

async function fetchRows(path: string): Promise<Array<Record<string, unknown>>> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      Accept: 'application/json',
    },
  })
  if (!res.ok) throw new Error(`Supabase ${res.status}`)
  return res.json()
}

type SiteUrl = { loc: string; lastmod?: string }

async function collectUrls(origin: string): Promise<SiteUrl[]> {
  const urls: SiteUrl[] = [
    { loc: `${origin}/` },
    { loc: `${origin}/productos` },
    { loc: `${origin}/tiendas` },
    { loc: `${origin}/jornada` },
  ]

  const stores = (await fetchRows(
    'stores?select=slug,created_at&is_verified=eq.true&order=created_at.asc&limit=1000',
  )) as Array<{ slug: string; created_at: string }>
  for (const store of stores) {
    if (store.slug) urls.push({ loc: `${origin}/tiendas/${encodeURIComponent(store.slug)}`, lastmod: store.created_at })
  }

  const products = (await fetchRows(
    'products?select=id,created_at&is_active=eq.true&order=created_at.asc&limit=1000',
  )) as Array<{ id: string; created_at: string }>
  for (const product of products) {
    urls.push({ loc: `${origin}/productos/${product.id}`, lastmod: product.created_at })
  }

  return urls
}

export default async (request: Request) => {
  const { origin } = new URL(request.url)

  let urls: SiteUrl[]
  try {
    urls =
      SUPABASE_URL && SUPABASE_ANON_KEY
        ? await collectUrls(origin)
        : [{ loc: `${origin}/` }, { loc: `${origin}/productos` }, { loc: `${origin}/tiendas` }]
  } catch {
    urls = [{ loc: `${origin}/` }, { loc: `${origin}/productos` }, { loc: `${origin}/tiendas` }]
  }

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls
  .map(
    (u) =>
      `  <url>\n    <loc>${esc(u.loc)}</loc>${
        u.lastmod ? `\n    <lastmod>${new Date(u.lastmod).toISOString()}</lastmod>` : ''
      }\n  </url>`,
  )
  .join('\n')}
</urlset>`

  return new Response(body, {
    headers: {
      'content-type': 'application/xml; charset=utf-8',
      'cache-control': 'public, max-age=3600',
    },
  })
}
