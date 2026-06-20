<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Edit2, Trash2, Lock, Unlock, ShieldAlert, RefreshCw } from 'lucide-vue-next'

const DEPT_CONFIG = {
  corretor:    { label: 'Corretor',    color: '#4338ca', bg: 'rgba(67,56,202,0.1)' },
  suporte:     { label: 'Suporte',     color: '#059669', bg: 'rgba(5,150,105,0.1)' },
  financeiro:  { label: 'Financeiro',  color: '#d97706', bg: 'rgba(217,119,6,0.1)' },
  manutencao:  { label: 'Manutenção',  color: '#ea580c', bg: 'rgba(234,88,12,0.1)' },
}
import api from '../api'
import { useAgentsStore } from '../store/agents'
import { storeToRefs } from 'pinia'

const router = useRouter()
const agentsStore = useAgentsStore()
const { agents, isLoading } = storeToRefs(agentsStore)
const currentUser = ref(null)
const togglingId = ref(null)

const fetchAgents = () => agentsStore.fetchAgents()

onMounted(() => {
  const stored = localStorage.getItem('user')
  if (stored) currentUser.value = JSON.parse(stored)
  fetchAgents()
})

const queueAgents = computed(() =>
  [...agents.value]
    .filter(a => a.available_for_roundrobin && a.status === 'active' && a.department === 'corretor')
    .sort((a, b) => (a.queue_position ?? 9999) - (b.queue_position ?? 9999))
)

const blockAgent = async (agent) => {
  if (!confirm(`Deseja bloquear ${agent.first_name}?`)) return
  try {
    await api.patch(`/agents/${agent.id}/block`)
    fetchAgents()
  } catch (e) { console.error(e) }
}

const unblockAgent = async (agent) => {
  try {
    await api.patch(`/agents/${agent.id}/unblock`)
    fetchAgents()
  } catch (e) { console.error(e) }
}

const deleteAgent = async (id) => {
  if (!confirm('Tem certeza que deseja apagar este corretor permanentemente?')) return
  try {
    await api.delete(`/agents/${id}`)
    fetchAgents()
  } catch (e) { console.error(e) }
}

const toggleRoundRobin = async (agent) => {
  togglingId.value = agent.id
  try {
    const res = await api.patch(`/agents/${agent.id}/toggle_roundrobin`)
    const idx = agents.value.findIndex(a => a.id === agent.id)
    if (idx !== -1) {
      agents.value[idx] = { ...agents.value[idx], ...res.data }
    }
  } catch (e) {
    console.error('Erro ao alterar rodízio', e)
  } finally {
    togglingId.value = null
  }
}
</script>

<template>
  <div class="page-container">
    <div class="page-header">
      <div class="header-content">
        <h1>Agentes (Corretores)</h1>
        <button class="btn-primary" @click="router.push('/agentes/novo')">
          <Plus class="icon-sm" /> Novo Agente
        </button>
      </div>
    </div>

    <!-- Fila de Rodízio -->
    <div class="queue-card" v-if="queueAgents.length > 0">
      <div class="queue-header">
        <RefreshCw class="icon-sm" />
        <span>Fila de Rodízio — Corretores</span>
        <span class="queue-hint">Novos leads são atribuídos ao 1º da fila</span>
      </div>
      <div class="queue-list">
        <div v-for="(agent, idx) in queueAgents" :key="agent.id" class="queue-item">
          <span class="queue-pos">{{ idx + 1 }}º</span>
          <span class="queue-name">{{ agent.first_name }} {{ agent.last_name }}</span>
          <span v-if="idx === 0" class="queue-next-badge">próximo</span>
        </div>
      </div>
    </div>
    <div class="queue-empty" v-else-if="!isLoading">
      <RefreshCw class="icon-sm" /> Nenhum agente na fila de rodízio. Ative o rodízio nos agentes abaixo.
    </div>

    <!-- Tabela de Agentes -->
    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Status</th>
            <th>Nome</th>
            <th>Departamento</th>
            <th>E-mail</th>
            <th>WhatsApp</th>
            <th>Rodízio</th>
            <th width="120">Ações</th>
          </tr>
        </thead>
        <tbody>
          <template v-if="isLoading">
            <tr v-for="i in 3" :key="'skel'+i" class="skeleton-row">
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-action"></div></td>
            </tr>
          </template>
          <tr v-else-if="agents.length === 0">
            <td colspan="7" class="text-center py-4 text-muted">Nenhum agente cadastrado.</td>
          </tr>
          <tr v-for="agent in agents" :key="agent.id" :class="{'row-blocked': agent.status === 'blocked'}">
            <td>
              <span :class="['badge', agent.status === 'blocked' ? 'badge-danger' : 'badge-success']">
                {{ agent.status === 'blocked' ? 'Bloqueado' : 'Ativo' }}
              </span>
            </td>
            <td class="font-medium">
              {{ agent.first_name }} {{ agent.last_name }}
              <div v-if="agent.role === 'empresa' || agent.role === 'admin'" class="badge-admin inline">
                <ShieldAlert class="icon-xs" /> Dono
              </div>
            </td>
            <td>
              <span
                class="dept-badge"
                :style="{
                  color: (DEPT_CONFIG[agent.department] || DEPT_CONFIG.corretor).color,
                  background: (DEPT_CONFIG[agent.department] || DEPT_CONFIG.corretor).bg
                }"
              >
                {{ (DEPT_CONFIG[agent.department] || DEPT_CONFIG.corretor).label }}
              </span>
            </td>
            <td>{{ agent.email }}</td>
            <td>{{ agent.phone || '-' }}</td>
            <td>
              <template v-if="agent.department === 'corretor' || !agent.department">
                <button
                  class="toggle-btn"
                  :class="{ 'toggle-on': agent.available_for_roundrobin, 'toggle-loading': togglingId === agent.id }"
                  :disabled="togglingId === agent.id || agent.status === 'blocked'"
                  @click="toggleRoundRobin(agent)"
                  :title="agent.available_for_roundrobin ? 'Remover da fila de rodízio' : 'Adicionar à fila de rodízio'"
                >
                  <span class="toggle-track"><span class="toggle-thumb"></span></span>
                  <span class="toggle-label">
                    {{ agent.available_for_roundrobin ? `${queueAgents.findIndex(a => a.id === agent.id) + 1}º na fila` : 'Desligado' }}
                  </span>
                </button>
              </template>
              <span v-else class="text-xs text-muted">— encaminhado pela IA</span>
            </td>
            <td class="actions-cell">
              <button class="btn-icon" @click="router.push(`/agentes/${agent.id}/editar`)" title="Editar">
                <Edit2 class="icon-sm" />
              </button>
              <template v-if="currentUser && agent.id !== currentUser.id">
                <button v-if="agent.status === 'active'" class="btn-icon text-warning" @click="blockAgent(agent)" title="Bloquear">
                  <Lock class="icon-sm" />
                </button>
                <button v-else class="btn-icon text-success" @click="unblockAgent(agent)" title="Desbloquear">
                  <Unlock class="icon-sm" />
                </button>
                <button class="btn-icon text-danger" @click="deleteAgent(agent.id)" title="Excluir">
                  <Trash2 class="icon-sm" />
                </button>
              </template>
              <template v-else>
                <span class="text-xs text-muted" style="margin-left:0.5rem">(Você)</span>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  height: 100%;
}

.page-header {
  margin-bottom: 1.5rem;
  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    h1 { font-size: 1.2rem; color: var(--text-main); font-weight: 500; }
  }
}

.queue-card {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-left: 4px solid #4338ca;
  border-radius: 8px;
  padding: 1rem 1.25rem;
  margin-bottom: 1.25rem;

  .queue-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text-main);
    margin-bottom: 0.75rem;

    .queue-hint {
      font-weight: 400;
      font-size: 0.78rem;
      color: var(--text-muted);
      margin-left: auto;
    }
  }

  .queue-list {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .queue-item {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    background: rgba(67,56,202,0.06);
    border: 1px solid rgba(67,56,202,0.15);
    border-radius: 20px;
    padding: 0.3rem 0.75rem;
    font-size: 0.82rem;

    .queue-pos {
      font-weight: 700;
      color: #4338ca;
      min-width: 1.5rem;
    }
    .queue-name { color: var(--text-main); font-weight: 500; }
    .queue-next-badge {
      background: #4338ca;
      color: white;
      font-size: 0.65rem;
      font-weight: 700;
      padding: 0.1rem 0.4rem;
      border-radius: 6px;
      text-transform: uppercase;
      letter-spacing: 0.03em;
    }
  }
}

.queue-empty {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--text-muted);
  font-size: 0.85rem;
  margin-bottom: 1rem;
  padding: 0.75rem 1rem;
  background: var(--bg-secondary);
  border: 1px dashed var(--border-color);
  border-radius: 8px;
}

.table-container {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.data-table {
  width: 100%;
  border-collapse: collapse;

  th, td {
    padding: 0.9rem 1.2rem;
    text-align: left;
    border-bottom: 1px solid var(--border-color);
  }

  th {
    font-weight: 600;
    color: var(--text-main);
    font-size: 0.85rem;
    background: rgba(0,0,0,0.01);
  }

  td { color: var(--text-muted); font-size: 0.88rem; }

  tr {
    transition: background-color 0.2s;
    &:hover { background: rgba(67,56,202,0.02); }
    &.row-blocked { background: rgba(239,68,68,0.05); td { opacity: 0.7; } }
  }
}

/* Toggle switch */
.toggle-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem;

  &:disabled { opacity: 0.5; cursor: not-allowed; }

  .toggle-track {
    width: 36px;
    height: 20px;
    background: #d1d5db;
    border-radius: 10px;
    position: relative;
    transition: background 0.2s;
    flex-shrink: 0;

    .toggle-thumb {
      width: 14px;
      height: 14px;
      background: white;
      border-radius: 50%;
      position: absolute;
      top: 3px;
      left: 3px;
      transition: transform 0.2s;
      box-shadow: 0 1px 3px rgba(0,0,0,0.2);
    }
  }

  .toggle-label {
    font-size: 0.78rem;
    color: var(--text-muted);
    min-width: 60px;
  }

  &.toggle-on .toggle-track {
    background: #4338ca;
    .toggle-thumb { transform: translateX(16px); }
  }
  &.toggle-on .toggle-label { color: #4338ca; font-weight: 600; }

  &.toggle-loading .toggle-track { opacity: 0.6; }
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.65rem;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 500;
  &.badge-success { background: rgba(16,185,129,0.15); color: #065f46; }
  &.badge-danger { background: rgba(239,68,68,0.15); color: #991b1b; }
}

.badge-admin {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  background: #4338ca;
  color: white;
  padding: 0.2rem 0.6rem;
  border-radius: 4px;
  font-size: 0.7rem;
  font-weight: 600;
  &.inline { margin-left: 0.4rem; vertical-align: middle; }
}

.dept-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.65rem;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 600;
}

.actions-cell { display: flex; gap: 0.5rem; }

.btn-icon {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 0.4rem;
  border-radius: 4px;
  display: flex;
  align-items: center;
  color: var(--text-muted);
  &:hover { background: rgba(0,0,0,0.05); }
  &.text-warning:hover { color: #d97706; background: rgba(217,119,6,0.1); }
  &.text-success:hover { color: #10b981; background: rgba(16,185,129,0.1); }
  &.text-danger:hover { color: #ef4444; background: rgba(239,68,68,0.1); }
}

.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  background: var(--primary);
  color: white;
  border: none;
  padding: 0.6rem 1.2rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
}

.skeleton-row {
  animation: pulse-skeleton 1.5s infinite;
  .skeleton-line { height: 12px; background: #e5e7eb; border-radius: 4px; width: 120px; &.short { width: 60px; } }
  .skeleton-action { height: 24px; width: 24px; background: #e5e7eb; border-radius: 4px; }
}
@keyframes pulse-skeleton {
  0% { opacity: 0.6; } 50% { opacity: 1; } 100% { opacity: 0.6; }
}

.icon-sm { width: 16px; height: 16px; }
.icon-xs { width: 12px; height: 12px; }
.font-medium { font-weight: 500; color: var(--text-main); }
.text-center { text-align: center; }
.py-4 { padding: 1.5rem 0; }
.text-xs { font-size: 0.75rem; }
.text-muted { color: var(--text-muted); }
</style>
