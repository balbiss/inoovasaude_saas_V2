<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Edit2, Trash2, Stethoscope, Phone, Mail, Search, LayoutGrid, List } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const professionals = ref([])
const isLoading = ref(false)
const searchQuery = ref('')
const viewMode = ref('list')

const filtered = computed(() => {
  const q = searchQuery.value.toLowerCase()
  if (!q) return professionals.value
  return professionals.value.filter(p =>
    p.name?.toLowerCase().includes(q) ||
    p.specialty?.toLowerCase().includes(q) ||
    p.council_number?.toLowerCase().includes(q)
  )
})

const fetchProfessionals = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get('/professionals')
    professionals.value = data
  } catch (e) {
    console.error(e)
  } finally {
    isLoading.value = false
  }
}

onMounted(fetchProfessionals)

const deleteProfessional = async (id) => {
  const result = await Swal.fire({
    title: 'Excluir profissional?',
    text: 'Esta ação não pode ser desfeita.',
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#d33',
    cancelButtonColor: '#6b7280',
    confirmButtonText: 'Sim, excluir',
    cancelButtonText: 'Cancelar'
  })
  if (!result.isConfirmed) return
  try {
    await api.delete(`/professionals/${id}`)
    professionals.value = professionals.value.filter(p => p.id !== id)
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Profissional excluído!', showConfirmButton: false, timer: 2500 })
  } catch {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao excluir.', showConfirmButton: false, timer: 2500 })
  }
}
</script>

<template>
  <div class="professionals-page">
    <div class="page-header">
      <div class="header-left">
        <Stethoscope class="header-icon" />
        <h1>Profissionais</h1>
        <span class="count-badge">{{ professionals.length }}</span>
      </div>
      <div class="header-right">
        <div class="search-box">
          <Search class="search-icon" />
          <input v-model="searchQuery" type="text" placeholder="Buscar profissional..." />
        </div>
        <div class="view-toggle">
          <button :class="['toggle-btn', viewMode === 'list' && 'active']" @click="viewMode = 'list'" title="Lista">
            <List class="icon-sm" />
          </button>
          <button :class="['toggle-btn', viewMode === 'grid' && 'active']" @click="viewMode = 'grid'" title="Grade">
            <LayoutGrid class="icon-sm" />
          </button>
        </div>
        <button class="btn-primary" @click="router.push('/profissionais/novo')">
          <Plus class="icon-sm" /> Novo Profissional
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="loading-state">Carregando profissionais...</div>

    <div v-else-if="filtered.length === 0" class="empty-state">
      <Stethoscope class="empty-icon" />
      <p>Nenhum profissional cadastrado.</p>
      <button class="btn-primary" @click="router.push('/profissionais/novo')">
        <Plus class="icon-sm" /> Adicionar Profissional
      </button>
    </div>

    <!-- MODO LISTA -->
    <div v-else-if="viewMode === 'list'" class="professionals-table-wrap">
      <table class="professionals-table">
        <thead>
          <tr>
            <th>Nome</th>
            <th>Especialidade</th>
            <th>Registro</th>
            <th>Telefone</th>
            <th>E-mail</th>
            <th>Status</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="prof in filtered" :key="prof.id">
            <td>
              <div class="row-name">
                <div class="row-avatar">{{ (prof.name || '?')[0].toUpperCase() }}</div>
                <span>{{ prof.name }}</span>
              </div>
            </td>
            <td><span class="specialty-badge">{{ prof.specialty }}</span></td>
            <td class="text-muted">{{ prof.council_number || '—' }}</td>
            <td class="text-muted">{{ prof.phone || '—' }}</td>
            <td class="text-muted">{{ prof.email || '—' }}</td>
            <td>
              <div class="status-cell">
                <span class="status-dot" :class="prof.status === 'active' ? 'active' : 'inactive'"></span>
                {{ prof.status === 'active' ? 'Ativo' : 'Inativo' }}
              </div>
            </td>
            <td>
              <div class="row-actions">
                <button class="btn-icon" @click="router.push(`/profissionais/${prof.id}/editar`)">
                  <Edit2 class="icon-sm" />
                </button>
                <button class="btn-icon danger" @click="deleteProfessional(prof.id)">
                  <Trash2 class="icon-sm" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- MODO GRADE -->
    <div v-else class="professionals-grid">
      <div v-for="prof in filtered" :key="prof.id" class="professional-card">
        <div class="card-avatar">
          {{ (prof.name || '?')[0].toUpperCase() }}
        </div>
        <div class="card-info">
          <h3>{{ prof.name }}</h3>
          <span class="specialty-badge">{{ prof.specialty }}</span>
          <p v-if="prof.council_number" class="council">{{ prof.council_number }}</p>
          <div class="contact-row" v-if="prof.phone">
            <Phone class="icon-xs" />
            <span>{{ prof.phone }}</span>
          </div>
          <div class="contact-row" v-if="prof.email">
            <Mail class="icon-xs" />
            <span>{{ prof.email }}</span>
          </div>
        </div>
        <div class="card-status">
          <span class="status-dot" :class="prof.status === 'active' ? 'active' : 'inactive'"></span>
          <span>{{ prof.status === 'active' ? 'Ativo' : 'Inativo' }}</span>
        </div>
        <div class="card-actions">
          <button class="btn-icon" @click="router.push(`/profissionais/${prof.id}/editar`)">
            <Edit2 class="icon-sm" />
          </button>
          <button class="btn-icon danger" @click="deleteProfessional(prof.id)">
            <Trash2 class="icon-sm" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.professionals-page { padding: 24px; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; flex-wrap: wrap; gap: 12px; }
.header-left { display: flex; align-items: center; gap: 10px; }
.header-left h1 { font-size: 1.5rem; font-weight: 700; color: var(--text-main); }
.header-icon { width: 28px; height: 28px; color: var(--primary); }
.count-badge { background: var(--bg-tertiary); color: var(--text-muted); font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; }
.header-right { display: flex; align-items: center; gap: 10px; }
.search-box { display: flex; align-items: center; gap: 6px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 12px; }
.search-box input { border: none; background: transparent; color: var(--text-main); outline: none; font-size: 0.875rem; width: 180px; }
.search-icon { width: 14px; height: 14px; color: var(--text-muted); }

.view-toggle { display: flex; border: 1px solid var(--border-color); border-radius: 8px; overflow: hidden; }
.toggle-btn { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border: none; background: var(--bg-secondary); color: var(--text-muted); cursor: pointer; transition: background 0.15s; }
.toggle-btn:hover { background: var(--bg-hover); }
.toggle-btn.active { background: var(--primary); color: #fff; }

.btn-primary { display: flex; align-items: center; gap: 6px; background: var(--primary); color: #fff; border: none; border-radius: 8px; padding: 8px 16px; font-size: 0.875rem; font-weight: 600; cursor: pointer; }
.btn-primary:hover { opacity: 0.9; }
.loading-state, .empty-state { text-align: center; padding: 64px 24px; color: var(--text-muted); }
.empty-icon { width: 48px; height: 48px; margin: 0 auto 12px; color: var(--text-muted); display: block; }

/* TABELA */
.professionals-table-wrap { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; overflow: hidden; }
.professionals-table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
.professionals-table thead tr { border-bottom: 1px solid var(--border-color); }
.professionals-table th { padding: 10px 14px; text-align: left; font-size: 0.75rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; white-space: nowrap; }
.professionals-table tbody tr { border-bottom: 1px solid var(--border-color); transition: background 0.1s; }
.professionals-table tbody tr:last-child { border-bottom: none; }
.professionals-table tbody tr:hover { background: var(--bg-hover); }
.professionals-table td { padding: 10px 14px; color: var(--text-main); vertical-align: middle; }
.text-muted { color: var(--text-muted) !important; }

.row-name { display: flex; align-items: center; gap: 10px; font-weight: 600; white-space: nowrap; }
.row-avatar { width: 32px; height: 32px; border-radius: 50%; background: var(--primary); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 0.875rem; font-weight: 700; flex-shrink: 0; }

.status-cell { display: flex; align-items: center; gap: 6px; font-size: 0.8rem; white-space: nowrap; }
.status-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.status-dot.active { background: #10b981; }
.status-dot.inactive { background: #ef4444; }

.row-actions { display: flex; gap: 6px; justify-content: flex-end; }

/* GRADE */
.professionals-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }
.professional-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 20px; display: flex; flex-direction: column; gap: 12px; }
.card-avatar { width: 56px; height: 56px; border-radius: 50%; background: var(--primary); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: 700; }
.card-info h3 { font-size: 1rem; font-weight: 600; color: var(--text-main); margin: 0 0 6px; }
.council { font-size: 0.75rem; color: var(--text-muted); margin-top: 4px; }
.contact-row { display: flex; align-items: center; gap: 6px; font-size: 0.8rem; color: var(--text-muted); margin-top: 4px; }
.card-status { display: flex; align-items: center; gap: 6px; font-size: 0.8rem; color: var(--text-muted); }
.card-actions { display: flex; gap: 8px; margin-top: auto; }

.specialty-badge { background: #ecfdf5; color: #065f46; font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; font-weight: 600; }
.icon-xs { width: 12px; height: 12px; }
.icon-sm { width: 16px; height: 16px; }
.btn-icon { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border: 1px solid var(--border-color); border-radius: 6px; background: var(--bg-primary); cursor: pointer; color: var(--text-main); }
.btn-icon:hover { background: var(--bg-hover); }
.btn-icon.danger:hover { background: #fee2e2; color: #ef4444; border-color: #ef4444; }
</style>
