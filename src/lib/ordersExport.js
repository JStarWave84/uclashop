import { supabase } from '@/lib/supabaseClient'
import { statusLabels } from '@/lib/mock'
import { formatPrice } from '@/lib/utils'

const STORE_NAME = 'UCLA Shop'
const ITEM_COLUMNS =
  'order_id, product_name_snapshot, variant_attributes_snapshot, price_snapshot, quantity'

// Cache of order_items by order id. Order lines never change once created,
// so it is safe to reuse them across exports during the session.
const itemCache = new Map()

export function cachedOrderItems(orderId) {
  return itemCache.get(orderId) || []
}

function chunk(array, size) {
  const out = []
  for (let i = 0; i < array.length; i += size) out.push(array.slice(i, i + size))
  return out
}

/**
 * Loads order_items for the given orders, skipping ids already cached.
 * Returns a Map<orderId, items[]>.
 */
export async function fetchOrderItems(orders) {
  const missing = orders.map((o) => o.id).filter((id) => !itemCache.has(id))

  for (const ids of chunk(missing, 100)) {
    const { data, error } = await supabase.from('order_items').select(ITEM_COLUMNS).in('order_id', ids)
    if (error) {
      console.error('fetchOrderItems', error)
      throw new Error('No se pudieron cargar los productos de las órdenes')
    }
    for (const id of ids) itemCache.set(id, [])
    for (const item of data || []) {
      if (!itemCache.has(item.order_id)) itemCache.set(item.order_id, [])
      itemCache.get(item.order_id).push(item)
    }
  }

  const map = new Map()
  for (const order of orders) map.set(order.id, itemCache.get(order.id) || [])
  return map
}

function variantLabel(attributes) {
  if (!attributes || typeof attributes !== 'object') return ''
  return Object.entries(attributes)
    .map(([key, value]) => `${key} ${value}`)
    .join(' · ')
}

function fullName(order) {
  return [order.customer_first_name, order.customer_last_name].filter(Boolean).join(' ').trim()
}

function formatDate(value) {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  return date.toLocaleString('es-VE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function itemsSummary(items) {
  return items
    .map((item) => {
      const variant = variantLabel(item.variant_attributes_snapshot)
      const name = variant
        ? `${item.product_name_snapshot} (${variant})`
        : item.product_name_snapshot
      return `${name} x${item.quantity}`
    })
    .join('\n')
}

function itemsCount(items) {
  return items.reduce((sum, item) => sum + (Number(item.quantity) || 0), 0)
}

// ── Rows ─────────────────────────────────────────────────────────────

const SUMMARY_HEADERS = [
  'Nro',
  'Fecha',
  'Cliente',
  'CI',
  'Teléfono',
  'Email',
  'Estado',
  'Referencia',
  'Comprobante',
  'Productos',
  'Artículos',
  'Total USD',
]

function buildSummaryRows(orders, itemsByOrder) {
  return orders.map((order) => {
    const items = itemsByOrder.get(order.id) || []
    return [
      order.id,
      formatDate(order.created_at),
      fullName(order),
      order.customer_ci || '',
      order.customer_phone || '',
      order.customer_email || '',
      statusLabels[order.status] || order.status,
      order.payment_reference || '',
      order.payment_receipt_url ? 'Sí' : 'No',
      itemsSummary(items),
      itemsCount(items),
      Number(order.total) || 0,
    ]
  })
}

const DETAIL_HEADERS = [
  'Nro orden',
  'Fecha',
  'Cliente',
  'Teléfono',
  'Producto',
  'Variante',
  'Precio USD',
  'Cantidad',
  'Subtotal USD',
]

function buildDetailRows(orders, itemsByOrder) {
  const rows = []
  for (const order of orders) {
    const items = itemsByOrder.get(order.id) || []
    if (!items.length) {
      rows.push([
        order.id,
        formatDate(order.created_at),
        fullName(order),
        order.customer_phone || '',
        '(sin productos)',
        '',
        0,
        0,
        0,
      ])
      continue
    }
    for (const item of items) {
      const price = Number(item.price_snapshot) || 0
      const quantity = Number(item.quantity) || 0
      rows.push([
        order.id,
        formatDate(order.created_at),
        fullName(order),
        order.customer_phone || '',
        item.product_name_snapshot,
        variantLabel(item.variant_attributes_snapshot),
        price,
        quantity,
        price * quantity,
      ])
    }
  }
  return rows
}

// ── Excel (.xlsx) ────────────────────────────────────────────────────

function applySheetLayout(XLSX, sheet, headers, rows, widths) {
  sheet['!cols'] = widths.map((width) => ({ wch: width }))
  sheet['!autofilter'] = {
    ref: XLSX.utils.encode_range({
      s: { r: 0, c: 0 },
      e: { r: rows.length, c: headers.length - 1 },
    }),
  }
}

function fileStamp() {
  const now = new Date()
  const pad = (value) => String(value).padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
}

export async function exportOrdersToXlsx(orders, itemsByOrder) {
  const mod = await import('xlsx')
  const XLSX = mod.default ?? mod

  const summaryRows = buildSummaryRows(orders, itemsByOrder)
  const detailRows = buildDetailRows(orders, itemsByOrder)

  const summarySheet = XLSX.utils.aoa_to_sheet([SUMMARY_HEADERS, ...summaryRows])
  applySheetLayout(XLSX, summarySheet, SUMMARY_HEADERS, summaryRows, [
    38, 18, 28, 14, 16, 30, 20, 18, 12, 46, 10, 14,
  ])

  const detailSheet = XLSX.utils.aoa_to_sheet([DETAIL_HEADERS, ...detailRows])
  applySheetLayout(XLSX, detailSheet, DETAIL_HEADERS, detailRows, [
    38, 18, 28, 16, 40, 26, 12, 10, 14,
  ])

  const workbook = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(workbook, summarySheet, 'Resumen')
  XLSX.utils.book_append_sheet(workbook, detailSheet, 'Detalle')
  XLSX.writeFile(workbook, `ordenes-uclashop-${fileStamp()}.xlsx`, { compression: true })
}

// ── PDF (print dialog) ───────────────────────────────────────────────

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function buildPrintHtml(orders, itemsByOrder, meta = {}) {
  const rows = buildSummaryRows(orders, itemsByOrder)
  const total = orders.reduce((sum, order) => sum + (Number(order.total) || 0), 0)

  const bodyRows = rows
    .map(
      (row) => `
        <tr>
          <td class="mono">${escapeHtml(row[0])}</td>
          <td class="nowrap">${escapeHtml(row[1])}</td>
          <td>${escapeHtml(row[2])}</td>
          <td class="nowrap">${escapeHtml(row[4])}</td>
          <td class="nowrap">${escapeHtml(row[6])}</td>
          <td>${escapeHtml(row[7])}</td>
          <td class="pre">${escapeHtml(row[9])}</td>
          <td class="num">${escapeHtml(formatPrice(row[11]))}</td>
        </tr>`
    )
    .join('')

  const metaLine = [meta.filters, `${orders.length} ${orders.length === 1 ? 'orden' : 'órdenes'}`]
    .filter(Boolean)
    .join(' · ')

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <title>Órdenes — ${escapeHtml(STORE_NAME)}</title>
  <style>
    @page { size: A4 landscape; margin: 12mm; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 16px;
      color: #171717;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
      font-size: 10px;
    }
    h1 { margin: 0; font-size: 18px; letter-spacing: -0.01em; }
    .brand { color: #6b7280; font-size: 11px; margin: 2px 0 0; }
    .meta {
      display: flex;
      justify-content: space-between;
      gap: 16px;
      margin: 10px 0 12px;
      padding-bottom: 8px;
      border-bottom: 1px solid #e5e5e5;
      color: #525252;
      font-size: 10px;
    }
    table { width: 100%; border-collapse: collapse; }
    thead th {
      background: #f5f5f5;
      border: 1px solid #d4d4d4;
      padding: 5px 6px;
      text-align: left;
      font-size: 9px;
      text-transform: uppercase;
      letter-spacing: 0.03em;
      color: #404040;
    }
    tbody td {
      border: 1px solid #e5e5e5;
      padding: 5px 6px;
      vertical-align: top;
    }
    tbody tr { page-break-inside: avoid; }
    tbody tr:nth-child(even) { background: #fafafa; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 8px; word-break: break-all; }
    .nowrap { white-space: nowrap; }
    .pre { white-space: pre-line; }
    .num { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; }
    tfoot td { border: 1px solid #e5e5e5; padding: 6px; font-weight: 600; }
    tfoot .num { text-align: right; }
    .toolbar {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
      margin-bottom: 12px;
    }
    .toolbar button {
      border: 1px solid #d4d4d4;
      background: #fff;
      border-radius: 6px;
      padding: 7px 14px;
      font-size: 12px;
      cursor: pointer;
    }
    .toolbar button.primary { background: #1f2937; border-color: #1f2937; color: #fff; }
    @media print {
      body { padding: 0; }
      .toolbar { display: none; }
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <button onclick="window.close()">Cerrar</button>
    <button class="primary" onclick="window.print()">Imprimir / Guardar PDF</button>
  </div>

  <header>
    <h1>Órdenes</h1>
    <p class="brand">${escapeHtml(STORE_NAME)} · Generado el ${escapeHtml(formatDate(new Date()))}</p>
  </header>

  <div class="meta">
    <span>${escapeHtml(metaLine)}</span>
    <span>Total: ${escapeHtml(formatPrice(total))}</span>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 12%">Nro</th>
        <th style="width: 10%">Fecha</th>
        <th style="width: 14%">Cliente</th>
        <th style="width: 9%">Teléfono</th>
        <th style="width: 9%">Estado</th>
        <th style="width: 8%">Referencia</th>
        <th style="width: 28%">Productos</th>
        <th style="width: 10%">Total</th>
      </tr>
    </thead>
    <tbody>${bodyRows}</tbody>
    <tfoot>
      <tr>
        <td colspan="7">Total de ${orders.length} ${orders.length === 1 ? 'orden' : 'órdenes'}</td>
        <td class="num">${escapeHtml(formatPrice(total))}</td>
      </tr>
    </tfoot>
  </table>
</body>
</html>`
}

/**
 * Opens a dedicated print document (so the admin layout does not interfere)
 * and triggers the browser print dialog, where the user can save as PDF.
 */
export function printOrdersReport(orders, itemsByOrder, meta = {}) {
  const win = window.open('', '_blank')
  if (!win) throw new Error('popup_blocked')

  const html = buildPrintHtml(orders, itemsByOrder, meta)
  win.opener = null
  win.document.open()
  win.document.write(html)
  win.document.close()
  win.focus()
  win.setTimeout(() => win.print(), 300)
}
