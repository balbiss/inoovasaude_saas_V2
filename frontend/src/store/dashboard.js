import { defineStore } from 'pinia'
import api from '../api'

const TTL = 30_000 // dashboard refreshes mais rápido (30s)

export const useDashboardStore = defineStore('dashboard', {
  state: () => ({
    kpis: {
      total_contacts:  0,
      retorno_count:   0,
      kanban:          { novo_paciente: 0, agendado: 0, compareceu: 0, retorno: 0 },
      conversations:   { open: 0, resolved: 0, today: 0, with_human: 0 },
      appointments:    { total: 0, today: 0, upcoming: 0, done: 0 }
    },
    leadsBySourceData: {
      labels: ['Sem dados'],
      datasets: [{ data: [1], backgroundColor: ['#e5e7eb'] }]
    },
    todayLeads: [],
    isOwner: false,
    isLoading: false,
    _cachedAt: 0,
  }),

  actions: {
    async fetchDashboard(force = false) {
      const fresh = this._cachedAt > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      if (!this._cachedAt) this.isLoading = true
      try {
        const res = await api.get('/dashboard')
        this.kpis       = res.data.kpis
        this.isOwner    = res.data.is_owner
        this.todayLeads = res.data.today_assigned_leads || []

        const sourceData = res.data.leads_by_source || {}
        const labels = Object.keys(sourceData)
        const data   = Object.values(sourceData)

        this.leadsBySourceData = labels.length
          ? { labels, datasets: [{ data, backgroundColor: ['#6366f1','#10b981','#f59e0b','#ef4444','#3b82f6','#ec4899','#0d9488','#8b5cf6'] }] }
          : { labels: ['Sem dados'], datasets: [{ data: [1], backgroundColor: ['#e5e7eb'] }] }

        this._cachedAt = Date.now()
      } catch (e) {
        console.error('fetchDashboard:', e)
      } finally {
        this.isLoading = false
      }
    },

    invalidate() { this._cachedAt = 0 },
  },
})
