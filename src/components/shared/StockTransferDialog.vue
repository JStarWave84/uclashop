<script setup>
import { ref, computed, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'vue-sonner'
import { ArrowLeftRight, Loader2 } from '@lucide/vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

const props = defineProps({
  open: { type: Boolean, default: false },
  product: { type: Object, default: null },
})

const emit = defineEmits(['update:open', 'transferred'])

const variants = ref([])
const selectedVariantId = ref('')
const direction = ref('to_store') // 'to_store' | 'to_warehouse'
const quantity = ref(1)
const loading = ref(false)
const saving = ref(false)

const selectedVariant = computed(() =>
  variants.value.find((v) => v.id === selectedVariantId.value) || null
)

const storeStock = computed(() => {
  if (selectedVariant.value) return Number(selectedVariant.value.stock) || 0
  return Number(props.product?.stock) || 0
})

const warehouseStock = computed(() => {
  if (selectedVariant.value) return Number(selectedVariant.value.stock_warehouse) || 0
  return Number(props.product?.stock_warehouse) || 0
})

const available = computed(() =>
  direction.value === 'to_store' ? warehouseStock.value : storeStock.value
)

function variantLabel(variant) {
  const entries = Object.entries(variant.attributes || {}).filter(
    ([key, value]) => String(key).trim() && String(value).trim()
  )
  if (!entries.length) return 'Variante'
  return entries.map(([key, value]) => `${key}: ${value}`).join(' · ')
}

watch(
  () => [props.open, props.product?.id],
  async ([isOpen, productId]) => {
    if (!isOpen || !productId) return

    direction.value = 'to_store'
    quantity.value = 1
    variants.value = []
    selectedVariantId.value = ''
    loading.value = !!props.product?.has_variants

    if (props.product?.has_variants) {
      const { data, error } = await supabase
        .from('product_variants')
        .select('id, attributes, stock, stock_warehouse')
        .eq('product_id', productId)
        .order('created_at')
      if (error) {
        console.error('fetchTransferVariants', error)
        toast.error('No se pudieron cargar las variantes')
      } else {
        variants.value = data || []
        selectedVariantId.value = variants.value[0]?.id || ''
      }
      loading.value = false
    }
  },
  { immediate: true }
)

function close() {
  emit('update:open', false)
}

async function submit() {
  if (saving.value || !props.product) return
  const qty = Number(quantity.value)
  if (!Number.isInteger(qty) || qty < 1) {
    toast.error('Ingresá una cantidad entera mayor que cero')
    return
  }
  if (qty > available.value) {
    toast.error('No hay suficientes unidades para transferir')
    return
  }

  saving.value = true
  const { data, error } = await supabase.rpc('transfer_stock', {
    p_product_id: props.product.id,
    p_variant_id: selectedVariantId.value || null,
    p_quantity: qty,
    p_to_store: direction.value === 'to_store',
  })
  saving.value = false

  if (error) {
    console.error('transfer_stock', error)
    toast.error(error.message || 'No se pudo transferir el stock')
    return
  }

  toast.success(
    direction.value === 'to_store'
      ? `${qty} unidad(es) movidas a tienda`
      : `${qty} unidad(es) movidas a depósito`
  )
  emit('transferred', data)
  close()
}
</script>

<template>
  <Dialog :open="open" @update:open="(value) => emit('update:open', value)">
    <DialogContent class="sm:max-w-md">
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2">
          <ArrowLeftRight class="size-4" />
          Transferir stock
        </DialogTitle>
        <DialogDescription class="break-words">
          {{ product?.name || 'Producto' }}
        </DialogDescription>
      </DialogHeader>

      <div v-if="loading" class="flex items-center gap-2 py-8 text-sm text-neutral-500">
        <Loader2 class="size-4 animate-spin" />
        Cargando variantes...
      </div>

      <div v-else class="space-y-4">
        <div class="grid grid-cols-2 gap-2 rounded-lg border border-neutral-200 p-2 text-center">
          <div>
            <p class="text-[10px] uppercase tracking-wide text-neutral-400">En tienda</p>
            <p class="text-lg font-semibold tabular-nums text-ucla-700">{{ storeStock }}</p>
            <p class="text-[10px] text-neutral-400">Vendible en la web</p>
          </div>
          <div class="border-l border-neutral-100">
            <p class="text-[10px] uppercase tracking-wide text-neutral-400">En depósito</p>
            <p class="text-lg font-semibold tabular-nums text-neutral-600">{{ warehouseStock }}</p>
            <p class="text-[10px] text-neutral-400">No disponible</p>
          </div>
        </div>

        <div v-if="product?.has_variants" class="grid gap-1.5">
          <Label class="text-xs text-neutral-500">Variante</Label>
          <Select v-model="selectedVariantId">
            <SelectTrigger>
              <SelectValue placeholder="Seleccionar variante..." />
            </SelectTrigger>
            <SelectContent>
              <SelectItem v-for="variant in variants" :key="variant.id" :value="variant.id">
                {{ variantLabel(variant) }} · Tienda {{ variant.stock }} / Depósito
                {{ variant.stock_warehouse }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div class="grid gap-1.5">
          <Label class="text-xs text-neutral-500">Dirección</Label>
          <div class="grid grid-cols-2 gap-2">
            <Button
              type="button"
              size="sm"
              :variant="direction === 'to_store' ? 'default' : 'outline'"
              :disabled="warehouseStock <= 0"
              @click="direction = 'to_store'"
            >
              Depósito → Tienda
            </Button>
            <Button
              type="button"
              size="sm"
              :variant="direction === 'to_warehouse' ? 'default' : 'outline'"
              :disabled="storeStock <= 0"
              @click="direction = 'to_warehouse'"
            >
              Tienda → Depósito
            </Button>
          </div>
        </div>

        <div class="grid gap-1.5">
          <Label for="transfer-qty" class="text-xs text-neutral-500">
            Cantidad (disponible: {{ available }})
          </Label>
          <Input
            id="transfer-qty"
            v-model="quantity"
            type="number"
            min="1"
            :max="available"
            :disabled="available <= 0 || loading"
          />
        </div>
      </div>

      <DialogFooter>
        <Button variant="ghost" :disabled="saving" @click="close">Cancelar</Button>
        <Button :disabled="saving || loading || available <= 0 || !quantity" @click="submit">
          <Loader2 v-if="saving" class="size-4 animate-spin" />
          {{ saving ? 'Transfiriendo...' : 'Transferir' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
