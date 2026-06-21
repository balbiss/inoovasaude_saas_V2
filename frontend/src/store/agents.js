import { defineStore } from 'pinia'
import api from '../api'

const TTL = 60_000

export const useAgentsStore = defineStore('agents', {
  state: () => ({
    agents: [],
    isLoading: false,
    _cachedAt: 0,
  }),

  actions: {
    async fetchAgents(force = false) {
      const fresh = this.agents.length > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      if (!this.agents.length) this.isLoading = true
      try {
        const res = await api.get('/agents')
        this.agents = res.data
        this._cachedAt = Date.now()
      } catch (e) {
        console.error('fetchAgents:', e)
      } finally {
        this.isLoading = false
      }
    },

    invalidate() { this._cachedAt = 0 },

    removeAgent(id) {
      this.agents = this.agents.filter(a => a.id !== id)
    },
  },
})
