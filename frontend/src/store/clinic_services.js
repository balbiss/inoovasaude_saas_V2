import { defineStore } from 'pinia'
import api from '../api'

export const useClinicServicesStore = defineStore('clinicServices', {
  state: () => ({
    services: [],
    isLoading: false,
    isLoadedOnce: false
  }),

  actions: {
    async fetchServices() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      try {
        const response = await api.get('/services')
        this.services = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch services:', error)
      } finally {
        this.isLoading = false
      }
    },

    removeService(id) {
      this.services = this.services.filter(s => s.id !== id)
    }
  }
})
