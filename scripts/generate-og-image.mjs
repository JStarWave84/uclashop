import { mkdirSync } from 'node:fs'
import { Buffer } from 'node:buffer'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import sharp from 'sharp'

const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '../public')
mkdirSync(outDir, { recursive: true })

const W = 1200
const H = 630

const svg = `
<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#120d4a"/>
      <stop offset="55%" stop-color="#2a1ab8"/>
      <stop offset="100%" stop-color="#4a30f2"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.85" cy="0.15" r="0.7">
      <stop offset="0%" stop-color="#f2a030" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#f2a030" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="url(#bg)"/>
  <rect width="${W}" height="${H}" fill="url(#glow)"/>
  <rect x="48" y="48" width="${W-96}" height="${H-96}" rx="32" fill="none" stroke="#f2a030" stroke-width="3" opacity="0.5"/>
  <text x="600" y="300" text-anchor="middle" font-family="Poppins, Arial, sans-serif" font-size="92" font-weight="700" fill="#ffffff" letter-spacing="2">UCLA Shop</text>
  <text x="600" y="380" text-anchor="middle" font-family="Poppins, Arial, sans-serif" font-size="36" font-weight="400" fill="#e0dcff" letter-spacing="6">TU TIENDA UNIVERSITARIA</text>
  <rect x="530" y="430" width="140" height="8" rx="4" fill="#f2a030"/>
  <text x="600" y="520" text-anchor="middle" font-family="Poppins, Arial, sans-serif" font-size="26" font-weight="500" fill="#c2b8ff" letter-spacing="3">COMUNIDAD · TIENDAS · PRODUCTOS</text>
</svg>
`

await sharp(Buffer.from(svg)).png().toFile(resolve(outDir, 'og-default.png'))
console.log('Generated public/og-default.png')
