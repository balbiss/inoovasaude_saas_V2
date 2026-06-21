import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'sw.js',
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png', 'icons.svg'],
      manifest: {
        name: 'InoovaSaúde',
        short_name: 'InoovaSaúde',
        description: 'CRM para clínicas — consultas, pacientes e conversas em um só lugar.',
        theme_color: '#0d9488',
        background_color: '#ffffff',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/dashboard',
        scope: '/',
        lang: 'pt-BR',
        categories: ['business', 'productivity'],
        icons: [
          { src: 'pwa-64x64.png',            sizes: '64x64',   type: 'image/png' },
          { src: 'pwa-192x192.png',           sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512x512.png',           sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'maskable-icon-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
        ]
      }
    })
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes('node_modules')) return
          if (id.includes('vue') || id.includes('pinia') || id.includes('vue-router')) return 'vendor-vue'
          if (id.includes('chart.js') || id.includes('vue-chartjs')) return 'vendor-charts'
          if (id.includes('sweetalert2') || id.includes('lucide')) return 'vendor-ui'
          if (id.includes('axios')) return 'vendor-axios'
        }
      }
    }
  }
})
