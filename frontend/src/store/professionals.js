import { defineStore } from 'pinia'
import api from '../api'

export const useProfessionalsStore = defineStore('professionals', {
  state: () => ({
    professionals: [],
    isLoading: false,
    isLoadedOnce: false
  }),

  actions: {
    async fetchProfessionals() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      try {
        const response = await api.get('/professionals')
        this.professionals = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch professionals:', error)
      } finally {
        this.isLoading = false
      }
    },

    removeProfessional(id) {
      this.professionals = this.professionals.filter(p => p.id !== id)
    }
  }
})
