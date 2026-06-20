<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Edit2, Trash2, Stethoscope, Phone, Mail, Search } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const professionals = ref([])
const isLoading = ref(false)
const searchQuery = ref('')

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
.professionals-page { padding: 24px; max-width: 1200px; margin: 0 auto; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; flex-wrap: wrap; gap: 12px; }
.header-left { display: flex; align-items: center; gap: 10px; }
.header-left h1 { font-size: 1.5rem; font-weight: 700; color: var(--text-main); }
.header-icon { width: 28px; height: 28px; color: var(--primary); }
.count-badge { background: var(--bg-tertiary); color: var(--text-muted); font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; }
.header-right { display: flex; align-items: center; gap: 10px; }
.search-box { display: flex; align-items: center; gap: 6px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 12px; }
.search-box input { border: none; background: transparent; color: var(--text-main); outline: none; font-size: 0.875rem; width: 180px; }
.search-icon { width: 14px; height: 14px; color: var(--text-muted); }
.btn-primary { display: flex; align-items: center; gap: 6px; background: var(--primary); color: #fff; border: none; border-radius: 8px; padding: 8px 16px; font-size: 0.875rem; font-weight: 600; cursor: pointer; }
.btn-primary:hover { opacity: 0.9; }
.loading-state, .empty-state { text-align: center; padding: 64px 24px; color: var(--text-muted); }
.empty-icon { width: 48px; height: 48px; margin: 0 auto 12px; color: var(--text-muted); display: block; }
.professionals-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; }
.professional-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 20px; display: flex; flex-direction: column; gap: 12px; }
.card-avatar { width: 56px; height: 56px; border-radius: 50%; background: var(--primary); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: 700; }
.card-info h3 { font-size: 1rem; font-weight: 600; color: var(--text-main); margin: 0 0 6px; }
.specialty-badge { background: #ecfdf5; color: #065f46; font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; font-weight: 600; }
.council { font-size: 0.75rem; color: var(--text-muted); margin-top: 4px; }
.contact-row { display: flex; align-items: center; gap: 6px; font-size: 0.8rem; color: var(--text-muted); margin-top: 4px; }
.icon-xs { width: 12px; height: 12px; }
.icon-sm { width: 16px; height: 16px; }
.card-status { display: flex; align-items: center; gap: 6px; font-size: 0.8rem; color: var(--text-muted); }
.status-dot { width: 8px; height: 8px; border-radius: 50%; }
.status-dot.active { background: #10b981; }
.status-dot.inactive { background: #ef4444; }
.card-actions { display: flex; gap: 8px; margin-top: auto; }
.btn-icon { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border: 1px solid var(--border-color); border-radius: 6px; background: var(--bg-primary); cursor: pointer; color: var(--text-main); }
.btn-icon:hover { background: var(--bg-hover); }
.btn-icon.danger:hover { background: #fee2e2; color: #ef4444; border-color: #ef4444; }
</style>
