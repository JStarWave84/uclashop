<script setup>
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Plus, Trash2, X, Layers } from '@lucide/vue'

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  errors: { type: Object, default: () => ({}) },
  disabled: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue'])

function emitUpdate(rows) {
  emit('update:modelValue', rows)
}

function addVariant() {
  emitUpdate([
    ...props.modelValue,
    { id: null, attrs: [{ k: '', v: '' }], price: '', stock: 0, stock_warehouse: 0 },
  ])
}

function removeVariant(index) {
  emitUpdate(props.modelValue.filter((_, i) => i !== index))
}

function addAttr(rowIndex) {
  const rows = props.modelValue.map((r, i) =>
    i === rowIndex ? { ...r, attrs: [...r.attrs, { k: '', v: '' }] } : r
  )
  emitUpdate(rows)
}

function removeAttr(rowIndex, attrIndex) {
  const rows = props.modelValue.map((r, i) =>
    i === rowIndex ? { ...r, attrs: r.attrs.filter((_, j) => j !== attrIndex) } : r
  )
  emitUpdate(rows)
}

function setAttr(rowIndex, attrIndex, field, value) {
  const rows = props.modelValue.map((r, i) => {
    if (i !== rowIndex) return r
    const attrs = r.attrs.map((a, j) => (j === attrIndex ? { ...a, [field]: value } : a))
    return { ...r, attrs }
  })
  emitUpdate(rows)
}

function setField(rowIndex, field, value) {
  const rows = props.modelValue.map((r, i) =>
    i === rowIndex ? { ...r, [field]: value } : r
  )
  emitUpdate(rows)
}
</script>

<template>
  <div class="space-y-3">
    <div
      v-for="(variant, index) in modelValue"
      :key="index"
      class="rounded-lg border border-neutral-200 bg-neutral-50/50 p-3"
    >
      <div class="flex items-center justify-between">
        <span class="inline-flex items-center gap-1.5 text-xs font-semibold text-neutral-600">
          <Layers class="size-3.5 text-ucla-600" />
          Variante {{ index + 1 }}
        </span>
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          class="text-neutral-400 hover:text-red-500"
          :disabled="disabled"
          @click="removeVariant(index)"
          aria-label="Eliminar variante"
        >
          <Trash2 class="size-3.5" />
        </Button>
      </div>

      <div class="mt-2 space-y-1.5">
        <div v-for="(pair, pi) in variant.attrs" :key="pi" class="flex items-center gap-2">
          <Input
            :model-value="pair.k"
            :disabled="disabled"
            placeholder="Atributo (ej. Color)"
            class="h-8 flex-1 text-xs"
            @update:model-value="(v) => setAttr(index, pi, 'k', v)"
          />
          <Input
            :model-value="pair.v"
            :disabled="disabled"
            placeholder="Valor (ej. Rojo)"
            class="h-8 flex-1 text-xs"
            @update:model-value="(v) => setAttr(index, pi, 'v', v)"
          />
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            class="shrink-0 text-neutral-300 hover:text-red-400"
            :disabled="disabled || variant.attrs.length <= 1"
            @click="removeAttr(index, pi)"
            aria-label="Quitar atributo"
          >
            <X class="size-3.5" />
          </Button>
        </div>
        <p v-if="errors[index]?.attributes" class="text-xs text-red-500">
          {{ errors[index].attributes }}
        </p>
        <button
          type="button"
          class="text-[11px] font-medium text-ucla-600 underline underline-offset-2 disabled:opacity-40"
          :disabled="disabled"
          @click="addAttr(index)"
        >
          + atributo
        </button>
      </div>

      <div class="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <div class="grid gap-1">
          <Label class="text-xs text-neutral-500">Precio (opcional)</Label>
          <Input
            :model-value="variant.price"
            :disabled="disabled"
            type="number"
            step="0.01"
            min="0"
            placeholder="Precio base"
            class="h-8 text-xs"
            :class="errors[index]?.price ? 'border-red-400' : ''"
            @update:model-value="(v) => setField(index, 'price', v)"
          />
          <p v-if="errors[index]?.price" class="text-xs text-red-500">{{ errors[index].price }}</p>
        </div>
        <div class="grid gap-1">
          <Label class="text-xs text-neutral-500">Tienda</Label>
          <Input
            :model-value="variant.stock"
            :disabled="disabled"
            type="number"
            min="0"
            placeholder="0"
            class="h-8 text-xs"
            :class="errors[index]?.stock ? 'border-red-400' : ''"
            @update:model-value="(v) => setField(index, 'stock', v)"
          />
          <p v-if="errors[index]?.stock" class="text-xs text-red-500">{{ errors[index].stock }}</p>
        </div>
        <div class="grid gap-1">
          <Label class="text-xs text-neutral-500">Depósito</Label>
          <Input
            :model-value="variant.stock_warehouse"
            :disabled="disabled"
            type="number"
            min="0"
            placeholder="0"
            class="h-8 text-xs"
            :class="errors[index]?.stock_warehouse ? 'border-red-400' : ''"
            @update:model-value="(v) => setField(index, 'stock_warehouse', v)"
          />
          <p v-if="errors[index]?.stock_warehouse" class="text-xs text-red-500">
            {{ errors[index].stock_warehouse }}
          </p>
        </div>
      </div>

      <p class="mt-1.5 text-[10px] text-neutral-400">
        Tienda = stock vendible en la web. Depósito = existencias no disponibles hasta transferir.
      </p>

      <p v-if="errors[index]?._" class="mt-1 text-xs text-red-500">{{ errors[index]._ }}</p>
    </div>

    <Button type="button" variant="outline" size="sm" :disabled="disabled" @click="addVariant">
      <Plus class="size-3.5" />
      Agregar variante
    </Button>
  </div>
</template>
