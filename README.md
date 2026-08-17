# UCLA Shop

E-commerce platform for the Universidad Centroccidental Lisandro Alvarado (UCLA). Built with Vue 3, Supabase, and Tailwind CSS.

## Features

### Shop (Customer-facing)
- Product catalog with search and filtering by sales session (*jornadas*)
- Product detail pages with description and pricing
- Shopping cart with quantity management; the sidebar opens automatically when a product is added
- **WhatsApp ordering** — regular orders are sent straight to WhatsApp using the product's contact number
- **Checkout flow** (customer info, payment reference, receipt upload) reserved for *jornadas* (active sales sessions)
- Products from an active jornada always go to checkout; mixing jornada and catalog products in the same cart is blocked
- Order confirmation with WhatsApp sharing and clipboard copy
- VES price tooltip (hover over USD prices to see the equivalent in bolívares)

### Admin Dashboard
- **Dashboard** — stats overview (total orders, pending payment, paid, in delivery) and recent orders
- **Products** — full CRUD with image upload, stock tracking, backorder toggle, active/inactive status, and per-product WhatsApp contact number
- **Sales Sessions** — create and manage *jornadas* with product assignment
- **Orders** — list with search and status filtering; detail view with line items, receipt viewer, and status management
- **Deliveries** — list view (read-only) for tracking delivery status
- **Payment Accounts** — CRUD for bank accounts and mobile payment options (shown at jornada checkout)
- Authentication with Supabase Auth (email/password), route guards, and session persistence

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | [Vue 3](https://vuejs.org/) with `<script setup>` |
| Routing | [Vue Router](https://router.vuejs.org/) |
| State | [Pinia](https://pinia.vuejs.org/) + persisted state |
| Backend | [Supabase](https://supabase.com/) (PostgreSQL, Auth, Storage) |
| Styling | [Tailwind CSS v4](https://tailwindcss.com/) |
| UI Library | [Reka UI](https://reka-ui.com/) (headless, Radix-inspired) |
| Icons | [Lucide](https://lucide.dev/) |
| Validation | [Zod](https://zod.dev/) |
| Notifications | [vue-sonner](https://sonner.emilkowal.ski/) |
| Linting | oxlint + ESLint + Prettier |
| Build | [Vite](https://vite.dev/) |

## Database Schema (PostgreSQL via Supabase)

```
profiles                  — Admin users (id references auth.users)
products                  — Product catalog with stock, pricing, and per-product WhatsApp contact (contact_phone)
sales_sessions            — Sales events / jornadas
product_sessions          — Many-to-many: products ↔ sessions
payment_accounts          — Bank accounts for manual payments
product_payment_accounts  — Preferred payment accounts per product
orders                    — Order headers with customer info and status
order_items               — Line items with price snapshots
deliveries                — Delivery tracking
```

Key behaviors enforced at the database level:
- Stock validation on order item insertion (unless backorder is allowed)
- Automatic `payment_account_id` assignment based on product preferences
- Row Level Security (RLS) — anonymous users can only insert orders; admins have full access
- Order history preserved even if products are deleted (`ON DELETE SET NULL`)

## Ordering Logic

- **Regular products**: adding to cart opens the sidebar, and the action is **"Comprar por WhatsApp"** — a pre-filled WhatsApp message (product list + total) is sent to the contact number configured on the first product (`contact_phone`, with a hardcoded fallback number in `src/lib/whatsapp.js`).
- **Jornadas (active sales sessions)**: products of the open session always go through the **checkout flow** (`/checkout`), which is guarded by a route check that requires an open session. Checkout creates the order in the database (RPC `place_order`) and the confirmation page lets the customer notify the seller via WhatsApp.
- **No mixing**: if the cart already contains jornada products, adding catalog products is blocked (and vice versa), keeping carts either all-jornada or all-regular.

## Prerequisites

- **Node.js** ^20.19.0 or >=22.12.0
- **npm**
- A [Supabase](https://supabase.com/) project (free tier works)

## Environment Setup

Copy the following variables into a `.env.local` file:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

Both values are found in your Supabase project dashboard under **Settings → API**.

## Installation

```sh
npm install
```

## Development

```sh
npm run dev
```

Runs on `http://localhost:5173` by default.

## Build & Preview

```sh
npm run build
npm run preview
```

## Linting & Formatting

```sh
npm run lint       # oxlint + ESLint
npm run format     # Prettier
```

## Supabase Migrations

Migrations are located in `supabase/migrations/`. To apply them to your Supabase project:

1. Install the [Supabase CLI](https://supabase.com/docs/guides/cli)
2. Link your project: `supabase link --project-ref your-project-ref`
3. Run migrations: `supabase db push`

Alternatively, copy the contents of each migration file and run them in order in the Supabase SQL Editor.

A seed file is available at `supabase/seed.sql` for testing.

## Project Structure

```
src/
├── components/
│   ├── shared/          # Shared components (PriceDisplay)
│   ├── shop/            # Shop-specific components (CartDrawer, CheckoutForm, ProductCard, etc.)
│   ├── site/            # Layout components (AppHeader, DashboardSidebar, etc.)
│   └── ui/              # Reka UI wrappers (button, dialog, input, table, etc.)
├── composables/         # Vue composables (useExchangeRate)
├── lib/                 # Utilities (supabaseClient, utils, mock data)
├── router/              # Vue Router configuration
├── schemas/             # Zod validation schemas
├── stores/              # Pinia stores (auth, cart)
└── views/
    ├── dashboard/       # Admin pages (login, products, orders, sessions, etc.)
    └── shop/            # Customer-facing pages (catalog, cart, checkout, etc.)
```

## License

MIT
