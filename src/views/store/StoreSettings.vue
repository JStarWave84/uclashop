<script setup>
import { ref, computed, onMounted } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Save, ImageUp, Trash2, Store, ShieldCheck, Clock } from '@lucide/vue'
import { toast } from 'vue-sonner'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { storeLogoUrl } from '@/lib/storage'

const auth = useAuthStore()

const form = ref({
  name: '',
  slug: '',
  description: '',
  phone: '',
})
const logoFile = ref(null)
const logoPreview = ref(null)
const logoPath = ref(null)
const slugTouched = ref(false)
const saving = ref(false)
const updatingName = ref(false)
const userNameForm = ref('')

function slugify(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/[\s_]+/g, '-')
}

const validSlug = computed(() => /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(form.value.slug))

onMounted(() => {
  if (auth.store) {
    form.value = {
      name: auth.store.name || '',
      slug: auth.store.slug || '',
      description: auth.store.description || '',
      phone: auth.store.phone || '',
    }
    logoPath.value = auth.store.logo_path || null
    logoPreview.value = auth.store.logo_path ? storeLogoUrl(auth.store.logo_path) : null
    userNameForm.value = auth.userName || ''
  }
})

function onStoreNameInput() {
  if (!slugTouched.value) form.value.slug = slugify(form.value.name)
}

function onSlugInput() {
  slugTouched.value = true
  form.value.slug = slugify(form.value.slug)
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
  logoPath.value = null
  logoPreview.value = null
}

async function handleSave() {
  if (!form.value.name.trim()) return toast.error('El nombre es obligatorio')
  if (!validSlug.value) return toast.error('El slug solo puede tener letras, números y guiones')

  saving.value = true
  try {
    let newLogoPath = logoPath.value
    if (logoFile.value) {
      const ext = logoFile.value.name.split('.').pop()
      newLogoPath = `${auth.storeId}/logo.${ext}`
      const { error: upErr } = await supabase.storage
        .from('store-logos')
        .upload(newLogoPath, logoFile.value, { upsert: true })
      if (upErr) {
        toast.error('No se pudo subir el logo')
        console.error(upErr)
        return
      }
      if (auth.store?.logo_path && auth.store.logo_path !== newLogoPath) {
        await supabase.storage.from('store-logos').remove([auth.store.logo_path]).catch(() => {})
      }
    } else if (logoPreview.value === null && auth.store?.logo_path) {
      await supabase.storage.from('store-logos').remove([auth.store.logo_path]).catch(() => {})
      newLogoPath = null
    }

    const { error } = await supabase
      .from('stores')
      .update({
        name: form.value.name,
        slug: form.value.slug,
        description: form.value.description || null,
        phone: form.value.phone || null,
        logo_path: newLogoPath,
      })
      .eq('id', auth.storeId)
    if (error) {
      toast.error(error.message || 'No se pudo guardar')
      console.error(error)
      return
    }
    await auth.fetchSession()
    toast.success('Tienda actualizada')
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    saving.value = false
  }
}

async function updateUserName() {
  if (!userNameForm.value.trim()) return toast.error('El nombre es obligatorio')
  updatingName.value = true
  try {
    const { error } = await supabase.functions.invoke('admin-update-user', {
      body: {
        user_id: auth.user?.id,
        full_name: userNameForm.value.trim(),
      }
    })
    if (error) {
      toast.error(error.message || 'No se pudo actualizar el nombre')
      return
    }
    toast.success('Nombre actualizado')
    await auth.fetchSession()
    userNameForm.value = ''
  } catch (e) {
    console.error(e)
    toast.error('Error inesperado')
  } finally {
    updatingName.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-ucla-900" style="font-family: var(--font-display)">
          Ajustes de mi tienda
        </h1>
        <p class="mt-1 text-sm text-neutral-500">Datos públicos de tu tienda en el marketplace.</p>
      </div>
      <span
        class="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium"
        :class="auth.isVerifiedStore ? 'bg-emerald-50 text-emerald-600' : 'bg-amber-50 text-amber-600'"
      >
        <ShieldCheck v-if="auth.isVerifiedStore" class="size-3.5" />
        <Clock v-else class="size-3.5" />
        {{ auth.isVerifiedStore ? 'Verificada' : 'Pendiente' }}
      </span>
    </div>

    <form class="mt-8 space-y-5 rounded-xl border border-neutral-200 bg-white p-6" @submit.prevent="handleSave">
      <div class="grid gap-2">
        <Label>Logo</Label>
        <div class="flex items-center gap-3">
          <div class="flex size-20 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-neutral-200 bg-neutral-50">
            <img v-if="logoPreview" :src="logoPreview" alt="Logo" class="size-full object-cover" />
            <Store v-else class="size-8 text-neutral-300" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="cursor-pointer">
              <span class="inline-flex items-center gap-1.5 rounded-md border border-neutral-200 px-3 py-1.5 text-xs font-medium text-neutral-700 hover:bg-neutral-50">
                <ImageUp class="size-3.5" />
                Cambiar logo
              </span>
              <input type="file" accept="image/*" class="hidden" @change="onLogoSelected" />
            </label>
            <Button v-if="logoPreview" type="button" variant="ghost" size="sm" class="text-red-500" @click="removeLogo">
              <Trash2 class="size-3.5" />
              Quitar logo
            </Button>
          </div>
        </div>
      </div>

      <div class="grid gap-2">
        <Label for="set-name">Nombre de la tienda *</Label>
        <Input id="set-name" v-model="form.name" @input="onStoreNameInput" />
      </div>

      <div class="grid gap-2">
        <Label for="set-slug">URL *</Label>
        <div class="flex items-center gap-2">
          <span class="text-sm text-neutral-400">/tiendas/</span>
          <Input
            id="set-slug"
            v-model="form.slug"
            :class="form.slug && !validSlug ? 'border-red-400' : ''"
            @input="onSlugInput"
          />
        </div>
        <p v-if="form.slug && !validSlug" class="text-xs text-red-500">
          Solo letras, números y guiones.
        </p>
      </div>

      <div class="grid gap-2">
        <Label for="set-phone">Número de WhatsApp</Label>
        <Input id="set-phone" v-model="form.phone" type="tel" placeholder="0412-1234567" />
        <p class="text-xs text-neutral-400">
          Los pedidos de tus productos se envían a este número.
        </p>
      </div>

      <div class="grid gap-2">
        <Label for="set-desc">Descripción</Label>
        <Textarea id="set-desc" v-model="form.description" rows="3" />
      </div>

      <div class="grid gap-2">
        <Label>Nombre de usuario *</Label>
        <Input v-model="userNameForm" placeholder="Tu nombre completo" />
      </div>

      <div class="grid gap-2">
        <Button variant="outline" @click="updateUserName" :disabled="updatingName">
          Actualizar nombre
        </Button>
        <Button type="submit" :disabled="saving">
          <Save class="size-4" />
          {{ saving ? 'Guardando...' : 'Guardar cambios' }}
        </Button>
      </div>
    </form>
  </div>
</template>