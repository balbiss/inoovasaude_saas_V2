import { defineStore } from 'pinia'
import api from '../api'

const TTL = 60_000

export const useContactsStore = defineStore('contacts', {
  state: () => ({
    contacts: [],
    isLoading: false,
    _cachedAt: 0,
  }),

  actions: {
    async fetchContacts(force = false) {
      const fresh = this.contacts.length > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      if (!this.contacts.length) this.isLoading = true
      try {
        const res = await api.get('/contacts')
        this.contacts = res.data
        this._cachedAt = Date.now()
      } catch (e) {
        console.error('fetchContacts:', e)
      } finally {
        this.isLoading = false
      }
    },

    invalidate() { this._cachedAt = 0 },

    removeContact(id) {
      this.contacts = this.contacts.filter(c => c.id !== id)
    },
  },
})
