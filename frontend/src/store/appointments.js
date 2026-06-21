import { defineStore } from 'pinia'
import api from '../api'

const TTL = 60_000
const META_TTL = 300_000 // meta (profissionais, serviços) dura 5 min

export const useAppointmentsStore = defineStore('appointments', {
  state: () => ({
    appointments: [],
    contacts: [],
    professionals: [],
    services: [],
    brokers: [],
    isLoading: false,
    _cachedAt: 0,
    _metaCachedAt: 0,
  }),

  actions: {
    async fetchMetaData(force = false) {
      const fresh = this._metaCachedAt > 0 && Date.now() - this._metaCachedAt < META_TTL
      if (!force && fresh) return

      try {
        const [resContacts, resProfs, resSvcs, resAgents] = await Promise.all([
          api.get('/contacts'),
          api.get('/professionals'),
          api.get('/services'),
          api.get('/agents'),
        ])
        this.contacts      = resContacts.data
        this.professionals = resProfs.data
        this.services      = resSvcs.data
        this.brokers       = resAgents.data.map(a => `${a.first_name || ''} ${a.last_name || ''}`.trim())
        this._metaCachedAt = Date.now()
      } catch (e) {
        console.error('fetchMetaData:', e)
      }
    },

    async fetchAppointments(force = false) {
      const fresh = this.appointments.length > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      if (!this.appointments.length) this.isLoading = true
      try {
        const res = await api.get('/appointments')
        this.appointments = res.data
        this._cachedAt = Date.now()
      } catch (e) {
        console.error('fetchAppointments:', e)
      } finally {
        this.isLoading = false
      }
    },

    invalidate() { this._cachedAt = 0 },
    invalidateMeta() { this._metaCachedAt = 0 },

    removeAppointment(id) {
      this.appointments = this.appointments.filter(a => a.id !== id)
    },
  },
})
