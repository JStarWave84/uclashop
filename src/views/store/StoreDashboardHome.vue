<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import {
  Store,
  Package,
  Settings,
  Users,
  ImageUp,
  Trash2,
  ShieldCheck,
  Clock,
} from '@lucide/vue'
import { toast } from 'vue-sonner'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { storeLogoUrl } from '@/lib/storage'
import { optimizeLogoImage } from '@/lib/imageOptimize'

const router = useRouter()
const auth = useAuthStore()

const productCount = ref(0)
const loading = ref(true)

const setupForm = ref({
  store_name: '',
  slug: '',
  description: '',
  phone: '',
})
const logoFile = ref(null)
const logoPreview = ref(null)
const slugTouched = ref(false)
const saving = ref(false)

function slugify(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/[\s_]+/g, '-')
}

const validSlug = computed(() => /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(setupForm.value.slug))

function onStoreNameInput() {
  if (!slugTouched.value) setupForm.value.slug = slugify(setupForm.value.store_name)
}

function onSlugInput() {
  slugTouched.value = true
  setupForm.value.slug = slugify(setupForm.value.slug)
}

function onLogoSelected(e) {
  const file = e.target.files?.[0]
  if (!file) return
  if (!file.type.startsWith('image/')) {
    toast.error('Solo se permiten imágenes')
    return
  }
  logoFile.value = file
  logoPreview.value = URL.createObjectURL(file)
  e.target.value = ''
}

function removeLogo() {
  logoFile.value = null
  logoPreview.value = null
}

onMounted(async () => {
  if (auth.storeId) {
    const { count, error } = await supabase
      .from('products')
      .select('id', { count: 'exact', head: true })
      .eq('store_id', auth.storeId)
    if (!error) productCount.value = count || 0
  }
  loading.value = false
})

async function createStore() {
  if (!setupForm.value.store_name.trim()) return toast.error('Ingresá el nombre de tu tienda')
  if (!validSlug.value) return toast.error('El slug solo puede tener letras, números y guiones')
  if (!setupForm.value.phone.trim()) return toast.error('Ingresá tu número de WhatsApp')

  saving.value = true
  try {
    const { data: storeId, error } = await supabase.rpc('create_store', {
      p_name: setupForm.value.store_name,
      p_slug: setupForm.value.slug,
      p_description: setupForm.value.description || null,
      p_phone: setupForm.value.phone || null,
      p_logo_path: null,
    })
    if (error) {
      toast.error(error.message || 'No se pudo crear la tienda')
      return
    }
    if (logoFile.value) {
      const optimized = await optimizeLogoImage(logoFile.value)
      const ext = optimized.name.split('.').pop()
      const path = `${storeId}/logo.${ext}`
      const { error: upErr } = await supabase.storage
        .from('store-logos')
        .upload(path, optimized, { upsert: true })
      if (upErr) {
        console.error('uploadLogo', upErr)
      } else {
        await supabase.from('stores').update({ logo_path: path }).eq('id', storeId)
      }
    }
    localStorage.removeItem('ucla_pending_store')
    localStorage.removeItem('ucla_pending_logo')
    await auth.fetchSession()
    toast.success('Tienda registrada. Esperá la verificación del Centro de Estudiantes.')
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    saving.value = false
  }
}

const quickLinks = computed(() => [
  { to: '/tienda/productos', icon: Package, label: 'Mis productos', desc: 'Administrá tu catálogo e inventario' },
  { to: '/tienda/ajustes', icon: Settings, label: 'Ajustes', desc: 'Datos de tu tienda y WhatsApp' },
  { to: '/tienda/miembros', icon: Users, label: 'Miembros', desc: 'Invitá a tu equipo' },
])

const pendingLogo = computed(() => logoPreview.value)
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
    <template v-if="!auth.store">
      <div class="mx-auto max-w-lg">
        <div class="rounded-xl border border-ucla-100 bg-white p-6">
          <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
            Completá el registro de tu tienda
          </h1>
          <p class="mt-1 text-sm text-ucla-900/50">
            Tu cuenta ya está creada. Falta definir los datos de tu tienda para poder publicar.
          </p>

          <form class="mt-6 space-y-4" @submit.prevent="createStore">
            <div class="grid gap-2">
              <Label for="setup-name">Nombre de la tienda *</Label>
              <Input id="setup-name" v-model="setupForm.store_name" placeholder="Ej: Empanadas La UCLA" @input="onStoreNameInput" />
            </div>
            <div class="grid gap-2">
              <Label for="setup-slug">URL *</Label>
              <div class="flex items-center gap-2">
                <span class="text-sm text-ucla-900/40">/tiendas/</span>
                <Input
                  id="setup-slug"
                  v-model="setupForm.slug"
                  placeholder="empanadas-la-ucla"
                  :class="setupForm.slug && !validSlug ? 'border-red-400' : ''"
                  @input="onSlugInput"
                />
              </div>
              <p v-if="setupForm.slug && !validSlug" class="text-xs text-red-500">
                Solo letras, números y guiones.
              </p>
            </div>
            <div class="grid gap-2">
              <Label for="setup-phone">Número de WhatsApp *</Label>
              <Input id="setup-phone" v-model="setupForm.phone" type="tel" placeholder="0412-1234567" />
            </div>
            <div class="grid gap-2">
              <Label for="setup-desc">Descripción</Label>
              <Textarea id="setup-desc" v-model="setupForm.description" rows="3" placeholder="Contanos brevemente sobre tu tienda..." />
            </div>
            <div class="grid gap-2">
              <Label>Logo</Label>
              <div class="flex items-center gap-3">
                <div class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-full border border-neutral-200 bg-neutral-50">
                  <img v-if="pendingLogo" :src="pendingLogo" alt="Logo" class="size-full object-cover" />
                  <Store v-else class="size-6 text-neutral-300" />
                </div>
                <div class="flex flex-col gap-1.5">
                  <label class="cursor-pointer">
                    <span class="inline-flex items-center gap-1.5 rounded-md border border-neutral-200 px-3 py-1.5 text-xs font-medium text-neutral-700 hover:bg-neutral-50">
                      <ImageUp class="size-3.5" />
                      Subir logo
                    </span>
                    <input type="file" accept="image/*" class="hidden" @change="onLogoSelected" />
                  </label>
                  <Button v-if="logoPreview" type="button" variant="ghost" size="sm" class="text-red-500" @click="removeLogo">
                    <Trash2 class="size-3.5" />
                    Quitar
                  </Button>
                </div>
              </div>
            </div>
            <Button type="submit" class="w-full" :disabled="saving">
              <Store class="size-4" />
              {{ saving ? 'Guardando...' : 'Crear mi tienda' }}
            </Button>
          </form>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex items-center gap-4">
          <div class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-neutral-200 bg-neutral-50">
            <img
              v-if="auth.store.logo_path"
              :src="storeLogoUrl(auth.store.logo_path)"
              :alt="auth.store.name"
              class="size-full object-cover"
            />
            <Store v-else class="size-8 text-neutral-300" />
          </div>
          <div>
            <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
              {{ auth.store.name }}
            </h1>
            <p class="mt-0.5 text-sm text-ucla-900/50">/tiendas/{{ auth.store.slug }}</p>
          </div>
        </div>

        <span
          class="inline-flex w-fit items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium"
          :class="auth.isVerifiedStore ? 'bg-emerald-50 text-emerald-600' : 'bg-amber-50 text-amber-600'"
        >
          <ShieldCheck v-if="auth.isVerifiedStore" class="size-3.5" />
          <Clock v-else class="size-3.5" />
          {{ auth.isVerifiedStore ? 'Tienda verificada' : 'En espera de verificación' }}
        </span>
      </div>

      <div
        v-if="!auth.isVerifiedStore"
        class="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-700"
      >
        Tu tienda está <strong>pendiente de verificación</strong> del Centro de Estudiantes. Mientras
        tanto podés preparar tu perfil, pero <strong>no podés publicar productos</strong>. Esto suele
        tomar poco tiempo.
      </div>

      <div class="mt-8 grid gap-4 sm:grid-cols-3">
        <div
          v-for="link in quickLinks"
          :key="link.to"
          class="rounded-xl border border-neutral-200 bg-white p-4 transition-colors hover:border-ucla-200"
        >
          <button class="flex w-full items-start gap-3 text-left" @click="router.push(link.to)">
            <div class="flex size-10 shrink-0 items-center justify-center rounded-lg bg-ucla-50 text-ucla-600">
              <component :is="link.icon" class="size-5" />
            </div>
            <div>
              <p class="text-sm font-semibold text-neutral-900">{{ link.label }}</p>
              <p class="mt-0.5 text-xs text-neutral-500">{{ link.desc }}</p>
            </div>
          </button>
        </div>
      </div>

      <div class="mt-8 rounded-xl border border-neutral-200 bg-white p-5">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-xs text-neutral-500">Productos publicados</p>
            <p class="mt-1 text-3xl font-semibold text-neutral-900">{{ productCount }}</p>
          </div>
          <Button variant="outline" @click="router.push('/tienda/productos')">
            <Package class="size-4" />
            Ver productos
          </Button>
        </div>
      </div>
    </template>
  </div>
</template>