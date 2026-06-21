import { defineStore } from 'pinia'
import api from '../api'

const TTL = 60_000

export const useClinicServicesStore = defineStore('clinicServices', {
  state: () => ({
    services: [],
    isLoading: false,
    _cachedAt: 0,
  }),

  actions: {
    async fetchServices(force = false) {
      const fresh = this.services.length > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      if (!this.services.length) this.isLoading = true
      try {
        const res = await api.get('/services')
        this.services = res.data
        this._cachedAt = Date.now()
      } catch (e) {
        console.error('fetchServices:', e)
      } finally {
        this.isLoading = false
      }
    },

    invalidate() { this._cachedAt = 0 },

    removeService(id) {
      this.services = this.services.filter(s => s.id !== id)
    },
  },
})
