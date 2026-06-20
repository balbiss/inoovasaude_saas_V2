import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.scss'
import App from './App.vue'
import router from './router'

const app = createApp(App)
const pinia = createPinia()

// Diretiva global para fechar dropdowns ao clicar fora
app.directive('click-outside', {
  beforeMount(el, binding) {
    el._clickOutsideHandler = (event) => {
      if (!el.contains(event.target)) binding.value(event)
    }
    document.addEventListener('mousedown', el._clickOutsideHandler)
  },
  unmounted(el) {
    document.removeEventListener('mousedown', el._clickOutsideHandler)
  }
})

app.use(pinia)
app.use(router)

app.mount('#app')
