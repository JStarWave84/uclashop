<script setup>
import { ref, reactive } from 'vue'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { ChevronRight, Trash2, ImageUp } from '@lucide/vue'
import { validateCheckout } from '@/schemas/checkout'

const emit = defineEmits(['submit'])

const form = reactive({
  first_name: '',
  last_name: '',
  ci: '',
  phone: '',
  email: '',
  payment_reference: '',
})

const receiptInput = ref(null)
const receiptFile = ref(null)
const receiptPreview = ref(null)
const receiptName = ref('')
const dragOver = ref(false)

const formErrors = reactive({
  first_name: '',
  last_name: '',
  ci: '',
  phone: '',
  email: '',
  payment_reference: '',
})

function selectReceipt(file) {
  if (!file) return
  if (!file.type.startsWith('image/')) {
    receiptName.value = 'Solo imágenes'
    return
  }
  receiptFile.value = file
  receiptPreview.value = URL.createObjectURL(file)
  receiptName.value = file.name
}

function onFileChange(e) {
  selectReceipt(e.target?.files?.[0])
  e.target.value = ''
}

function onDrop(e) {
  dragOver.value = false
  selectReceipt(e.dataTransfer?.files?.[0])
}

function removeReceipt() {
  receiptFile.value = null
  receiptPreview.value = null
  receiptName.value = ''
}

function formatCi(e) {
  const digits = e.target.value.replace(/[^\d]/g, '').slice(0, 8)
  const formatted = digits ? `V-${digits}` : ''
  e.target.value = formatted
  form.ci = formatted
}

function formatPhone(e) {
  const digits = e.target.value.replace(/[^\d]/g, '').slice(0, 11)
  const formatted = digits.length > 4 ? digits.slice(0, 4) + '-' + digits.slice(4) : digits
  e.target.value = formatted
  form.phone = formatted
}

function formatPaymentRef(e) {
  const formatted = e.target.value.replace(/[^\d]/g, '')
  e.target.value = formatted
  form.payment_reference = formatted
}

function handleSubmit() {
  for (const key of Object.keys(formErrors)) formErrors[key] = ''

  const { valid, errors, data } = validateCheckout(form)
  if (!valid) {
    Object.assign(formErrors, errors)
    return
  }

  emit('submit', {
    ...data,
    receipt_name: receiptName.value,
    receipt_file: receiptFile.value,
  })
}
</script>

<template>
  <form @submit.prevent="handleSubmit" novalidate>
    <fieldset>
      <legend class="text-sm font-semibold text-ucla-900">Tus datos</legend>

      <div class="mt-4 grid gap-4 sm:grid-cols-2">
        <div>
          <label for="cf_first_name" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Nombre *
          </label>
          <Input
            id="cf_first_name"
            v-model="form.first_name"
            type="text"
            placeholder="Tu nombre"
            :class="formErrors.first_name ? 'border-red-400' : ''"
          />
          <p v-if="formErrors.first_name" class="mt-1 text-xs text-red-500">
            {{ formErrors.first_name }}
          </p>
        </div>

        <div>
          <label for="cf_last_name" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Apellido *
          </label>
          <Input
            id="cf_last_name"
            v-model="form.last_name"
            type="text"
            placeholder="Tu apellido"
            :class="formErrors.last_name ? 'border-red-400' : ''"
          />
          <p v-if="formErrors.last_name" class="mt-1 text-xs text-red-500">
            {{ formErrors.last_name }}
          </p>
        </div>

        <div>
          <label for="cf_ci" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Cédula *
          </label>
          <Input
            id="cf_ci"
            v-model="form.ci"
            type="text"
            placeholder="V-12345678"
            :class="formErrors.ci ? 'border-red-400' : ''"
            @input="formatCi"
          />
          <p v-if="formErrors.ci" class="mt-1 text-xs text-red-500">
            {{ formErrors.ci }}
          </p>
        </div>

        <div>
          <label for="cf_phone" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Teléfono *
          </label>
          <Input
            id="cf_phone"
            v-model="form.phone"
            type="tel"
            placeholder="0412-1234567"
            :class="formErrors.phone ? 'border-red-400' : ''"
            @input="formatPhone"
          />
          <p v-if="formErrors.phone" class="mt-1 text-xs text-red-500">
            {{ formErrors.phone }}
          </p>
        </div>

        <div class="sm:col-span-2">
          <label for="cf_email" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Correo electrónico *
          </label>
          <Input
            id="cf_email"
            v-model="form.email"
            type="email"
            placeholder="correo@ejemplo.com"
            :class="formErrors.email ? 'border-red-400' : ''"
          />
          <p v-if="formErrors.email" class="mt-1 text-xs text-red-500">
            {{ formErrors.email }}
          </p>
        </div>
      </div>
    </fieldset>

    <fieldset class="mt-8">
      <legend class="text-sm font-semibold text-ucla-900">Datos del pago</legend>

      <div class="mt-4 space-y-4">
        <div>
          <label for="cf_payment_ref" class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Referencia del pago *
          </label>
          <Input
            id="cf_payment_ref"
            v-model="form.payment_reference"
            type="text"
            placeholder="Solo números, ej: 123456"
            :class="formErrors.payment_reference ? 'border-red-400' : ''"
            @input="formatPaymentRef"
          />
          <p v-if="formErrors.payment_reference" class="mt-1 text-xs text-red-500">
            {{ formErrors.payment_reference }}
          </p>
        </div>

        <div>
          <label class="mb-1.5 block text-xs font-medium text-ucla-900/60">
            Comprobante de pago (imagen)
          </label>

          <div v-if="receiptPreview" class="flex items-start gap-3">
            <div
              class="size-20 shrink-0 overflow-hidden rounded-lg border border-ucla-200 bg-ucla-50"
            >
              <img :src="receiptPreview" class="size-full object-cover" alt="Comprobante" />
            </div>
            <div class="flex flex-col gap-1.5 pt-1">
              <p class="text-sm font-medium text-ucla-900 truncate max-w-48">{{ receiptName }}</p>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                class="text-red-500 hover:text-red-600 w-fit"
                @click="removeReceipt"
              >
                <Trash2 class="size-3.5" />
                Eliminar
              </Button>
            </div>
          </div>

          <label
            v-else
            class="relative flex cursor-pointer items-center gap-2 rounded-lg border-2 px-4 py-3 text-sm transition-colors"
            :class="
              dragOver
                ? 'border-ucla-500 bg-ucla-50 text-ucla-600'
                : 'border-dashed border-ucla-200 text-ucla-900/50 hover:border-ucla-400 hover:text-ucla-600'
            "
            @dragover.prevent="dragOver = true"
            @dragleave.prevent="dragOver = false"
            @drop.prevent="onDrop"
          >
            <input
              ref="receiptInput"
              type="file"
              accept="image/*"
              class="absolute inset-0 z-0 h-full w-full cursor-pointer opacity-0"
              @change="onFileChange"
            />
            <span class="relative z-10 flex items-center gap-2 pointer-events-none">
              <ImageUp class="size-4 shrink-0" />
              <span>Click o arrastra el comprobante</span>
            </span>
          </label>
        </div>
      </div>
    </fieldset>

    <div class="mt-8">
      <Button type="submit" size="lg" class="w-full sm:w-auto">
        Crear pedido
        <ChevronRight class="size-4" />
      </Button>
      <p class="mt-2 text-xs text-ucla-900/40">
        * Crear el pedido no genera un cobro automático. Te daremos las instrucciones para pagar.
      </p>
    </div>
  </form>
</template>
