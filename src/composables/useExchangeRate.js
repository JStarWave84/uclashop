import { ref, onMounted } from 'vue'

const CACHE_KEY = 'ucla_exchange_rate'
const CACHE_TTL = 6 * 60 * 60 * 1000

const rate = ref(null)
const loading = ref(true)
const error = ref(null)

export function useExchangeRate() {
  async function fetchRate() {
    const cached = localStorage.getItem(CACHE_KEY)
    if (cached) {
      try {
        const parsed = JSON.parse(cached)
        if (Date.now() - parsed.timestamp < CACHE_TTL) {
          rate.value = parsed.rate
          loading.value = false
          return
        }
      } catch {
        /* ignore */
      }
    }

    try {
      const res = await fetch('https://api.exchangerate-api.com/v4/latest/USD')
      const data = await res.json()
      rate.value = data.rates.VES
      localStorage.setItem(CACHE_KEY, JSON.stringify({ rate: rate.value, timestamp: Date.now() }))
    } catch (e) {
      error.value = e.message
      if (cached) {
        try {
          rate.value = JSON.parse(cached).rate
        } catch {
          /* ignore */
        }
      }
    } finally {
      loading.value = false
    }
  }

  if (rate.value === null) fetchRate()

  return { rate, loading, error }
}
