import { createApp } from 'vue'
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'
import { createHead } from '@unhead/vue/client'

import App from './App.vue'
import './assets/styles.css'
import router from './router'
import Sonner from 'vue-sonner'
import 'vue-sonner/style.css'

const app = createApp(App)

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)
app.use(pinia)
app.use(router)
app.use(Sonner)
app.use(createHead())

app.mount('#app')
