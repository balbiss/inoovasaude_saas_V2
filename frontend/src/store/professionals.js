import { defineStore } from 'pinia'
import api from '../api'

const TTL = 60_000

export const useProfessionalsStore = defineStore('professionals', {
  state: () => ({
    professionals: [],
    isLoading: false,
    _cachedAt: 0,
  }),

  actions: {
    async fetchProfessionals(force = false) {
      const fresh = this.professionals.length > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      if (!this.professionals.length) this.isLoading = true
      try {
        const res = await api.get('/professionals')
        this.professionals = res.data
        this._cachedAt = Date.now()
      } catch (e) {
        console.error('fetchProfessionals:', e)
      } finally {
        this.isLoading = false
      }
    },

    invalidate() { this._cachedAt = 0 },

    removeProfessional(id) {
      this.professionals = this.professionals.filter(p => p.id !== id)
    },
  },
})
