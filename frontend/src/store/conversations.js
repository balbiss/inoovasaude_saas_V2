import { defineStore } from 'pinia'
import api from '../api'

export const useConversationsStore = defineStore('conversations', {
  state: () => ({
    conversations: [],
    agents: [],
    activeConversationId: null,
    currentFilter: 'todos', // todos, minhas, nao-atribuidos
    sidebarFilter: 'all',
    sidebarInboxId: null,
    sortStatus: 'open',
    sortBy: 'latest',
    sortType: 'all',
    advancedFilters: [],
    ws: null,
    _cachedAt: 0,
    currentUser: (() => {
      try {
        return JSON.parse(localStorage.getItem('user')) || { first_name: 'Usuário', email: '' }
      } catch {
        return { first_name: 'Usuário', email: '' }
      }
    })()
  }),

  getters: {
    activeConversation(state) {
      return state.conversations.find(c => c.id === state.activeConversationId) || null
    },
    sidebarFilteredConversations(state) {
      let filtered = state.conversations

      // Sort Status filter
      if (state.sortStatus !== 'all') {
        filtered = filtered.filter(c => c.status === state.sortStatus)
      }

      // Sort Type filter
      if (state.sortType === 'unread') {
        filtered = filtered.filter(c => c.unread > 0)
      } else if (state.sortType === 'mentions') {
        filtered = filtered.filter(() => false) // Mock mentions
      }

      // Sidebar route param filter overrides
      if (state.sidebarFilter === 'mencoes') {
        filtered = filtered.filter(() => false) // Mock
      } else if (state.sidebarFilter === 'participantes') {
        filtered = filtered.filter(c => c.assignee !== state.currentUser.name) // Mock
      } else if (state.sidebarFilter === 'nao-atendidas') {
        filtered = filtered.filter(c => c.status === 'open' && c.unread > 0)
      }

      // Inbox Filter
      if (state.sidebarInboxId) {
        filtered = filtered.filter(c => String(c.inbox_id) === String(state.sidebarInboxId))
      }

      return filtered
    },
    filteredConversations(state) {
      let filtered = this.sidebarFilteredConversations
      
      if (state.currentFilter === 'minhas') {
        filtered = filtered.filter(c => c.assignee === state.currentUser.name)
      } else if (state.currentFilter === 'nao-atribuidos') {
        filtered = filtered.filter(c => !c.assignee)
      }
      
      // Apply advanced filters
      if (state.advancedFilters && state.advancedFilters.length > 0) {
        state.advancedFilters.forEach(filter => {
          if (!filter.attribute || !filter.operator || !filter.value) return;
          
          filtered = filtered.filter(c => {
            let actualValue;
            
            if (filter.attribute === 'status') {
              actualValue = c.status;
            } else if (filter.attribute === 'assignee') {
              actualValue = c.assignee || 'unassigned';
            }
            
            if (filter.operator === 'equal_to') {
              return actualValue === filter.value;
            } else if (filter.operator === 'not_equal_to') {
              return actualValue !== filter.value;
            }
            return true;
          });
        });
      }

      // Apply Sort By — spread to avoid mutating state.conversations in place
      if (state.sortBy === 'oldest') {
        filtered = [...filtered].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp))
      } else {
        filtered = [...filtered].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      }

      return filtered
    }
  },

  actions: {
    async fetchConversations(force = false) {
      const TTL = 30_000
      const fresh = this.conversations.length > 0 && Date.now() - this._cachedAt < TTL
      if (!force && fresh) return

      try {
        const response = await api.get('/conversations')
        // Preservar mensagens já carregadas para não perder o chat aberto
        const existing = Object.fromEntries(this.conversations.map(c => [c.id, c.messages]))
        this.conversations = response.data.map(c => ({
          ...c,
          messages: existing[c.id] || [],
        }))
        if (this.conversations.length > 0 && !this.activeConversationId) {
          this.activeConversationId = this.conversations[0].id
        }
        this._cachedAt = Date.now()
        this.setupWebSocket()
      } catch (error) {
        console.error('Error fetching conversations:', error)
      }
    },

    async loadMessages(conversationId, force = false) {
      const conv = this.conversations.find(c => c.id === conversationId)
      if (!conv) return
      if (!force && conv.messages && conv.messages.length > 0) return

      try {
        const res = await api.get(`/conversations/${conversationId}`)
        conv.messages = res.data.messages || []
        conv.contact  = res.data.contact
      } catch (e) {
        console.error('loadMessages:', e)
      }
    },

    async fetchAgents() {
      try {
        const response = await api.get('/agents')
        this.agents = response.data
      } catch (error) {
        console.error('Error fetching agents:', error)
      }
    },

    async assignConversation(conversationId, userId) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { user_id: userId }
        })

        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          // Update the local conversation state
          this.conversations[convIndex].assignee_id = response.data.assignee_id
          this.conversations[convIndex].assignee = response.data.assignee
        }
      } catch (error) {
        console.error('Error assigning conversation:', error)
        throw error
      }
    },

    async transferConversation(conversationId, userId, note) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { user_id: userId },
          transfer_note: note
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].assignee_id = response.data.assignee_id
          this.conversations[convIndex].assignee = response.data.assignee
        }
        return response.data
      } catch (error) {
        console.error('Error transferring conversation:', error)
        throw error
      }
    },

    setActiveConversation(id) {
      this.activeConversationId = id
      const conv = this.conversations.find(c => c.id === id)
      if (conv) {
        conv.unread = 0
        this.loadMessages(id, true) // sempre recarrega ao selecionar
      }
    },

    setFilter(filterType) {
      this.currentFilter = filterType
    },

    setSidebarFilter(filterType) {
      this.sidebarFilter = filterType
      this.sidebarInboxId = null
    },

    setSidebarInboxId(inboxId) {
      this.sidebarInboxId = inboxId
      this.sidebarFilter = null
    },

    setSortFilters({ status, sortBy, type }) {
      this.sortStatus = status
      this.sortBy = sortBy
      this.sortType = type
    },

    setAdvancedFilters(filters) {
      this.advancedFilters = filters
    },

    async sendMessage(text, isPrivate = false, file = null) {
      if (!this.activeConversationId || (!text.trim() && !file)) return

      try {
        let response;
        if (file) {
          const formData = new FormData()
          formData.append('text', text)
          formData.append('is_private', isPrivate)
          formData.append('attachment', file)
          response = await api.post(`/conversations/${this.activeConversationId}/messages`, formData, {
            headers: {
              'Content-Type': 'multipart/form-data'
            }
          })
        } else {
          response = await api.post(`/conversations/${this.activeConversationId}/messages`, {
            text,
            is_private: isPrivate
          })
        }
        const newMsg = response.data.message
        const conv = this.conversations.find(c => c.id === this.activeConversationId)
        if (conv) {
          if (!conv.messages) conv.messages = []
          const exists = conv.messages.some(m => m.id === newMsg.id)
          if (!exists) {
            conv.messages.push(newMsg)
          }
          conv.preview = newMsg.text
          conv.timestamp = newMsg.timestamp
        }
      } catch (error) {
        console.error('Error sending message:', error)
      }
    },

    async updateContact(contactId, data) {
      try {
        const response = await api.put(`/contacts/${contactId}`, { contact: data })
        // Update contact in all conversations that match
        this.conversations.forEach(c => {
          if (c.contact && c.contact.id === contactId) {
            Object.assign(c.contact, response.data)
          }
        })
      } catch (error) {
        console.error('Error updating contact:', error)
        throw error
      }
    },

    async deleteContact(contactId) {
      try {
        await api.delete(`/contacts/${contactId}`)
        // Remove conversations belonging to this contact
        this.conversations = this.conversations.filter(c => !c.contact || c.contact.id !== contactId)
        if (this.activeConversation && this.activeConversation.contact.id === contactId) {
          this.activeConversationId = null
        }
      } catch (error) {
        console.error('Error deleting contact:', error)
        throw error
      }
    },

    async addNote(contactId, content) {
      try {
        const response = await api.post(`/contacts/${contactId}/add_note`, { content })
        
        // Update contact notes in all conversations that match
        this.conversations.forEach(c => {
          if (c.contact && c.contact.id === contactId) {
            if (!c.contact.notes) c.contact.notes = []
            c.contact.notes.unshift({
              id: response.data.id,
              content: response.data.content,
              created_at: response.data.created_at,
              author: response.data.user?.first_name || 'Sistema'
            })
          }
        })
      } catch (error) {
        console.error('Error adding note:', error)
        throw error
      }
    },

    async mergeContact(contactId, targetContactId) {
      try {
        await api.post(`/contacts/${contactId}/merge`, { target_contact_id: targetContactId })
        // Re-fetch everything because conversations were moved
        await this.fetchConversations()
      } catch (error) {
        console.error('Error merging contact:', error)
        throw error
      }
    },

    async updateConversationStatus(conversationId, status) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { status }
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].status = response.data.status
          this.conversations[convIndex].snoozed_until = response.data.snoozed_until || null
        }
      } catch (error) {
        console.error('Error updating conversation status:', error)
      }
    },

    async snoozeConversation(conversationId, snoozedUntil) {
      try {
        const response = await api.put(`/conversations/${conversationId}`, {
          conversation: { status: 'snoozed', snoozed_until: snoozedUntil }
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].status = 'snoozed'
          this.conversations[convIndex].snoozed_until = response.data.snoozed_until
        }
      } catch (error) {
        console.error('Error snoozing conversation:', error)
        throw error
      }
    },

    async resolveConversation(conversationId, { kanbanStage, sendClosingMessage, closingMessageText }) {
      try {
        await api.put(`/conversations/${conversationId}`, {
          conversation: { status: 'resolved' },
          kanban_stage:          kanbanStage || '',
          send_closing_message:  sendClosingMessage,
          closing_message_text:  closingMessageText || ''
        })
        const convIndex = this.conversations.findIndex(c => c.id === conversationId)
        if (convIndex !== -1) {
          this.conversations[convIndex].status = 'resolved'
          this.conversations[convIndex].snoozed_until = null
        }
      } catch (error) {
        console.error('Error resolving conversation:', error)
        throw error
      }
    },

    setupWebSocket() {
      if (this.ws) return

      let baseURL = api.defaults.baseURL
      if (!baseURL) {
        baseURL = window.location.origin.replace(':5173', ':3000')
      }

      const wsURL = baseURL.replace(/^http/, 'ws') + '/cable'
      const ws = new WebSocket(wsURL)
      this.ws = ws
      this._wsReconnectDelay = this._wsReconnectDelay || 3000

      ws.onopen = () => {
        this._wsReconnectDelay = 3000
        ws.send(JSON.stringify({
          command: 'subscribe',
          identifier: JSON.stringify({ channel: 'ConversationsChannel' })
        }))
      }

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'ping' || data.type === 'welcome' || data.type === 'confirm_subscription') return

          const payload = data.message
          if (!payload) return

          if (payload.event === 'message_created') {
            const { conversation_id, message: newMsg } = payload
            const conv = this.conversations.find(c => Number(c.id) === Number(conversation_id))
            if (conv) {
              if (!conv.messages) conv.messages = []
              const exists = conv.messages.some(m => m.id === newMsg.id)
              if (!exists) {
                conv.messages.push(newMsg)
                conv.preview = newMsg.text
                conv.timestamp = newMsg.timestamp
                if (Number(conversation_id) !== Number(this.activeConversationId)) {
                  conv.unread = (conv.unread || 0) + 1
                }
                window.dispatchEvent(new CustomEvent('new-message', {
                  detail: { conversationId: conversation_id }
                }))
              }
            } else {
              this.fetchConversations()
            }
          } else if (payload.event === 'message_updated') {
            const { conversation_id, message: updatedMsg } = payload
            const conv = this.conversations.find(c => Number(c.id) === Number(conversation_id))
            if (conv?.messages) {
              const existing = conv.messages.find(m => m.id === updatedMsg.id)
              if (existing) {
                Object.assign(existing, updatedMsg)
                window.dispatchEvent(new CustomEvent('new-message', { detail: { conversationId: conversation_id } }))
              }
            }
          } else if (payload.event === 'inbox_updated') {
            window.dispatchEvent(new CustomEvent('inbox-updated', { detail: payload }))
          } else if (payload.event === 'contact_updated') {
            if (payload.avatar_url) {
              this.conversations.forEach(conv => {
                if (conv.contact && Number(conv.contact.id) === Number(payload.contact_id)) {
                  conv.contact.avatar_url = payload.avatar_url
                }
              })
            }
            window.dispatchEvent(new CustomEvent('contact-updated', { detail: payload }))
          } else if (payload.event === 'conversation_tags_updated') {
            const conv = this.conversations.find(c => c.id === payload.conversation_id)
            if (conv) conv.tags = payload.tags
          } else if (payload.event === 'conversation_updated') {
            const idx = this.conversations.findIndex(c => Number(c.id) === Number(payload.conversation?.id))
            if (idx !== -1) Object.assign(this.conversations[idx], payload.conversation)
          } else if (payload.event === 'property_match_found') {
            window.dispatchEvent(new CustomEvent('property-match-found', { detail: payload }))
          } else if (payload.event === 'snooze_expired') {
            const conv = this.conversations.find(c => Number(c.id) === Number(payload.conversation_id))
            if (conv) {
              conv.status = 'open'
              conv.snoozed_until = null
            }
            window.dispatchEvent(new CustomEvent('snooze-expired', { detail: payload }))
          } else if (payload.event === 'lead_atribuido') {
            const me = this.currentUser
            if (Number(payload.assigned_to_user_id) === Number(me?.id)) {
              window.dispatchEvent(new CustomEvent('lead-atribuido', { detail: payload }))
            }
          } else if (payload.event === 'appointment_updated') {
            window.dispatchEvent(new CustomEvent('appointment-updated', { detail: payload }))
          }
        } catch (error) {
          console.error('WS message error:', error)
        }
      }

      ws.onclose = () => {
        this.ws = null
        const delay = Math.min(this._wsReconnectDelay || 3000, 30000)
        this._wsReconnectDelay = delay * 2
        setTimeout(() => this.fetchConversations(true), delay)
      }

      ws.onerror = () => {
        ws.close()
      }
    },

    // Polling confiável: atualiza sidebar e mensagens ativas a cada 5s
    startPolling() {
      if (this._pollInterval) return
      this._pollInterval = setInterval(async () => {
        // 1) Atualiza lista de conversas (sidebar: preview, unread, tags)
        try {
          const listRes = await api.get('/conversations')
          listRes.data.forEach(fresh => {
            const existing = this.conversations.find(c => Number(c.id) === Number(fresh.id))
            if (existing) {
              existing.preview   = fresh.preview
              existing.timestamp = fresh.timestamp
              existing.unread    = fresh.unread
              existing.status    = fresh.status
              existing.tags      = fresh.tags
              existing.assignee  = fresh.assignee
              existing.assignee_id = fresh.assignee_id
            } else {
              this.conversations.unshift({ ...fresh, messages: [] })
            }
          })
        } catch {}

        // 2) Atualiza mensagens da conversa ativa
        if (!this.activeConversationId) return
        try {
          const res = await api.get(`/conversations/${this.activeConversationId}`)
          const conv = this.conversations.find(c => Number(c.id) === Number(this.activeConversationId))
          if (conv && res.data.messages) {
            const prevLen = conv.messages?.length || 0
            conv.messages = res.data.messages
            if (conv.messages.length > prevLen) {
              window.dispatchEvent(new CustomEvent('new-message', {
                detail: { conversationId: this.activeConversationId }
              }))
            }
          }
        } catch {}
      }, 5000)
    },

    stopPolling() {
      if (this._pollInterval) {
        clearInterval(this._pollInterval)
        this._pollInterval = null
      }
    }
  }
})

