import { defineStore } from 'pinia'
import api from '../api'

export const useAppointmentsStore = defineStore('appointments', {
  state: () => ({
    appointments: [],
    contacts: [],
    professionals: [],
    services: [],
    brokers: [],
    isLoading: false,
    isLoadedOnce: false,
    isMetaLoaded: false
  }),

  actions: {
    async fetchMetaData() {
      if (this.isMetaLoaded) return;

      try {
        const [resContacts, resProfs, resSvcs, resAgents] = await Promise.all([
          api.get('/contacts'),
          api.get('/professionals'),
          api.get('/services'),
          api.get('/agents')
        ])
        this.contacts = resContacts.data
        this.professionals = resProfs.data
        this.services = resSvcs.data
        this.brokers = resAgents.data.map(a => `${a.first_name || ''} ${a.last_name || ''}`.trim())
        this.isMetaLoaded = true
      } catch (error) {
        console.error("Erro ao carregar listas:", error)
      }
    },
    async fetchAppointments() {
      if (!this.isLoadedOnce) {
        this.isLoading = true
      }
      
      try {
        const response = await api.get('/appointments')
        this.appointments = response.data
        this.isLoadedOnce = true
      } catch (error) {
        console.error('Failed to fetch appointments:', error)
      } finally {
        this.isLoading = false
      }
    },
    
    removeAppointment(id) {
      this.appointments = this.appointments.filter(a => a.id !== id)
    }
  }
})
