export default async (request: Request) => {
  const { origin } = new URL(request.url)

  const body = `User-agent: *
Allow: /
Disallow: /admin
Disallow: /tienda/
Disallow: /registro-tienda
Disallow: /checkout
Disallow: /carrito
Disallow: /orden

Sitemap: ${origin}/sitemap.xml`

  return new Response(body, {
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'cache-control': 'public, max-age=3600',
    },
  })
}
