<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Store, ImageUp, Trash2 } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { supabase } from '@/lib/supabaseClient'
import { optimizeLogoImage } from '@/lib/imageOptimize'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

const form = ref({
  full_name: '',
  email: '',
  password: '',
  store_name: '',
  slug: '',
  description: '',
  phone: '',
})
const logoFile = ref(null)
const logoPreview = ref(null)
const submitting = ref(false)
const slugTouched = ref(false)

function slugify(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/[\s_]+/g, '-')
}

function onStoreNameInput() {
  if (!slugTouched.value) {
    form.value.slug = slugify(form.value.store_name)
  }
}

function onSlugInput() {
  slugTouched.value = true
  form.value.slug = slugify(form.value.slug)
}

const validSlug = computed(() => /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(form.value.slug))

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

async function uploadLogo(storeId) {
  if (!logoFile.value) return null
  const optimized = await optimizeLogoImage(logoFile.value)
  const ext = optimized.name.split('.').pop()
  const path = `${storeId}/logo.${ext}`
  const { error } = await supabase.storage
    .from('store-logos')
    .upload(path, optimized, { upsert: true })
  if (error) {
    console.error('uploadLogo', error)
    throw error
  }
  return path
}

async function handleSubmit() {
  if (!form.value.full_name.trim()) return toast.error('Ingresá tu nombre')
  if (!form.value.email.trim()) return toast.error('Ingresá tu correo')
  if (form.value.password.length < 6) return toast.error('La contraseña debe tener al menos 6 caracteres')
  if (!form.value.store_name.trim()) return toast.error('Ingresá el nombre de tu tienda')
  if (!validSlug.value) return toast.error('El slug solo puede tener letras, números y guiones')

  submitting.value = true
  try {
    const { data, error } = await supabase.auth.signUp({
      email: form.value.email,
      password: form.value.password,
      options: {
        data: {
          full_name: form.value.full_name,
          account_type: 'store',
        },
      },
    })
    if (error) {
      toast.error(error.message || 'No se pudo crear la cuenta')
      return
    }

    const sessionAvailable = !!data?.session
    const pending = {
      store_name: form.value.store_name,
      slug: form.value.slug,
      description: form.value.description,
      phone: form.value.phone,
      has_logo: !!logoFile.value,
    }
    localStorage.setItem('ucla_pending_store', JSON.stringify(pending))
    if (logoFile.value) {
      localStorage.setItem('ucla_pending_logo', logoFile.value.name)
    }

    if (sessionAvailable) {
      await auth.fetchSession()
      const { error: storeErr } = await supabase.rpc('create_store', {
        p_name: form.value.store_name,
        p_slug: form.value.slug,
        p_description: form.value.description || null,
        p_phone: form.value.phone || null,
        p_logo_path: null,
      })
      if (storeErr) {
        toast.error(storeErr.message || 'No se pudo crear la tienda')
        return
      }
      if (logoFile.value) {
        const sid = auth.storeId
        const path = await uploadLogo(sid).catch((e) => {
          console.error(e)
          return null
        })
        if (path) {
          await supabase.from('stores').update({ logo_path: path }).eq('id', sid)
        }
      }
      localStorage.removeItem('ucla_pending_store')
      localStorage.removeItem('ucla_pending_logo')
      toast.success('Tienda registrada. Esperá la verificación del Centro de Estudiantes.')
      router.push('/tienda')
    } else {
      toast.success('Revisá tu correo para confirmar la cuenta. Al iniciar sesión completarás el registro de tu tienda.')
      router.push('/tienda/login')
    }
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div
    class="flex min-h-screen items-center justify-center bg-gradient-to-br from-ucla-50 via-white to-ucla-50 px-4 py-10"
  >
    <div class="w-full max-w-lg">
      <div class="mb-8 text-center">
        <h1
          class="text-3xl font-semibold tracking-tight text-ucla-900"
          style="font-family: var(--font-display)"
        >
          Registrá tu <span class="text-ucla-500">tienda</span>
        </h1>
        <p class="mt-1 text-sm text-ucla-900/50">
          Creá tu cuenta y esperá la verificación del Centro de Estudiantes para publicar productos.
        </p>
      </div>

      <form
        class="space-y-5 rounded-xl border border-ucla-100 bg-white p-6"
        @submit.prevent="handleSubmit"
      >
        <div class="grid gap-2">
          <Label for="reg-full-name">Tu nombre *</Label>
          <Input id="reg-full-name" v-model="form.full_name" placeholder="Nombre y apellido" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="grid gap-2">
            <Label for="reg-email">Correo electrónico *</Label>
            <Input id="reg-email" v-model="form.email" type="email" placeholder="tienda@ejemplo.com" />
          </div>
          <div class="grid gap-2">
            <Label for="reg-password">Contraseña *</Label>
            <Input id="reg-password" v-model="form.password" type="password" placeholder="••••••••" />
          </div>
        </div>

        <div class="grid gap-2">
          <Label for="reg-store-name">Nombre de la tienda *</Label>
          <Input
            id="reg-store-name"
            v-model="form.store_name"
            placeholder="Ej: Empanadas La UCLA"
            @input="onStoreNameInput"
          />
        </div>

        <div class="grid gap-2">
          <Label for="reg-slug">URL de tu tienda *</Label>
          <div class="flex items-center gap-2">
            <span class="text-sm text-ucla-900/40">/tiendas/</span>
            <Input
              id="reg-slug"
              v-model="form.slug"
              placeholder="empanadas-la-ucla"
              :class="form.slug && !validSlug ? 'border-red-400' : ''"
              @input="onSlugInput"
            />
          </div>
          <p v-if="form.slug && !validSlug" class="text-xs text-red-500">
            Solo letras, números y guiones.
          </p>
        </div>

        <div class="grid gap-2">
          <Label for="reg-phone">Número de WhatsApp *</Label>
          <Input id="reg-phone" v-model="form.phone" type="tel" placeholder="0412-1234567" />
          <p class="text-xs text-neutral-400">
            Los pedidos de tus productos se envían a este número.
          </p>
        </div>

        <div class="grid gap-2">
          <Label for="reg-desc">Descripción</Label>
          <Textarea
            id="reg-desc"
            v-model="form.description"
            rows="3"
            placeholder="Contanos brevemente sobre tu tienda..."
          />
        </div>

        <div class="grid gap-2">
          <Label>Logo</Label>
          <div class="flex items-center gap-3">
            <div
              class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-full border border-neutral-200 bg-neutral-50"
            >
              <img
                v-if="logoPreview"
                :src="logoPreview"
                alt="Logo"
                class="size-full object-cover"
              />
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
              <Button
                v-if="logoPreview"
                type="button"
                variant="ghost"
                size="sm"
                class="text-red-500"
                @click="removeLogo"
              >
                <Trash2 class="size-3.5" />
                Quitar
              </Button>
            </div>
          </div>
        </div>

        <Button type="submit" class="w-full" :disabled="submitting">
          <Store class="size-4" />
          {{ submitting ? 'Registrando...' : 'Crear mi tienda' }}
        </Button>
      </form>

      <p class="mt-6 text-center text-xs text-ucla-900/30">
        ¿Ya tenés cuenta?
        <router-link to="/tienda/login" class="font-medium text-ucla-600 underline">
          Iniciá sesión
        </router-link>
      </p>
    </div>
  </div>
</template>