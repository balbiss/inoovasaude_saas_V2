<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Edit2, Trash2, FlaskConical, Clock, DollarSign, Search } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const services = ref([])
const isLoading = ref(false)
const searchQuery = ref('')

const filtered = computed(() => {
  const q = searchQuery.value.toLowerCase()
  if (!q) return services.value
  return services.value.filter(s =>
    s.name?.toLowerCase().includes(q) ||
    s.category?.toLowerCase().includes(q)
  )
})

const fetchServices = async () => {
  isLoading.value = true
  try {
    const { data } = await api.get('/services')
    services.value = data
  } catch (e) {
    console.error(e)
  } finally {
    isLoading.value = false
  }
}

onMounted(fetchServices)

const formatPrice = (val) => val ? `R$ ${parseFloat(val).toFixed(2).replace('.', ',')}` : '—'
const formatDuration = (min) => {
  if (!min) return '—'
  return min >= 60 ? `${Math.floor(min / 60)}h${min % 60 > 0 ? ` ${min % 60}min` : ''}` : `${min}min`
}

const deleteService = async (id) => {
  const result = await Swal.fire({
    title: 'Excluir serviço?',
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
    await api.delete(`/services/${id}`)
    services.value = services.value.filter(s => s.id !== id)
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Serviço excluído!', showConfirmButton: false, timer: 2500 })
  } catch {
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao excluir.', showConfirmButton: false, timer: 2500 })
  }
}
</script>

<template>
  <div class="services-page">
    <div class="page-header">
      <div class="header-left">
        <FlaskConical class="header-icon" />
        <h1>Serviços</h1>
        <span class="count-badge">{{ services.length }}</span>
      </div>
      <div class="header-right">
        <div class="search-box">
          <Search class="search-icon" />
          <input v-model="searchQuery" type="text" placeholder="Buscar serviço..." />
        </div>
        <button class="btn-primary" @click="router.push('/servicos/novo')">
          <Plus class="icon-sm" /> Novo Serviço
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="loading-state">Carregando serviços...</div>

    <div v-else-if="filtered.length === 0" class="empty-state">
      <FlaskConical class="empty-icon" />
      <p>Nenhum serviço cadastrado.</p>
      <button class="btn-primary" @click="router.push('/servicos/novo')">
        <Plus class="icon-sm" /> Adicionar Serviço
      </button>
    </div>

    <div v-else class="services-list">
      <div v-for="svc in filtered" :key="svc.id" class="service-card">
        <div class="service-icon">
          <FlaskConical class="icon-md" />
        </div>
        <div class="service-info">
          <h3>{{ svc.name }}</h3>
          <span v-if="svc.category" class="category-badge">{{ svc.category }}</span>
          <p v-if="svc.description" class="description">{{ svc.description }}</p>
          <div class="service-meta">
            <span class="meta-item"><Clock class="icon-xs" /> {{ formatDuration(svc.duration_minutes) }}</span>
            <span class="meta-item"><DollarSign class="icon-xs" /> {{ formatPrice(svc.price) }}</span>
          </div>
        </div>
        <div class="service-status">
          <span class="status-dot" :class="svc.status === 'active' ? 'active' : 'inactive'"></span>
          <span>{{ svc.status === 'active' ? 'Ativo' : 'Inativo' }}</span>
        </div>
        <div class="card-actions">
          <button class="btn-icon" @click="router.push(`/servicos/${svc.id}/editar`)">
            <Edit2 class="icon-sm" />
          </button>
          <button class="btn-icon danger" @click="deleteService(svc.id)">
            <Trash2 class="icon-sm" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.services-page { padding: 24px; }
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
.loading-state, .empty-state { text-align: center; padding: 64px 24px; color: var(--text-muted); }
.empty-icon { width: 48px; height: 48px; margin: 0 auto 12px; color: var(--text-muted); display: block; }
.services-list { display: flex; flex-direction: column; gap: 12px; }
.service-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 16px 20px; display: flex; align-items: flex-start; gap: 16px; }
.service-icon { width: 44px; height: 44px; border-radius: 10px; background: #ecfdf5; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.icon-md { width: 22px; height: 22px; color: #065f46; }
.service-info { flex: 1; }
.service-info h3 { font-size: 1rem; font-weight: 600; color: var(--text-main); margin: 0 0 4px; }
.category-badge { background: #e0f2fe; color: #0369a1; font-size: 0.7rem; padding: 1px 7px; border-radius: 10px; font-weight: 600; }
.description { font-size: 0.8rem; color: var(--text-muted); margin: 6px 0 0; }
.service-meta { display: flex; gap: 16px; margin-top: 8px; }
.meta-item { display: flex; align-items: center; gap: 4px; font-size: 0.8rem; color: var(--text-muted); }
.icon-xs { width: 12px; height: 12px; }
.icon-sm { width: 16px; height: 16px; }
.service-status { display: flex; flex-direction: column; align-items: center; gap: 4px; font-size: 0.75rem; color: var(--text-muted); margin-top: 4px; }
.status-dot { width: 8px; height: 8px; border-radius: 50%; }
.status-dot.active { background: #10b981; }
.status-dot.inactive { background: #ef4444; }
.card-actions { display: flex; gap: 6px; }
.btn-icon { display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border: 1px solid var(--border-color); border-radius: 6px; background: var(--bg-primary); cursor: pointer; color: var(--text-main); }
.btn-icon:hover { background: var(--bg-hover); }
.btn-icon.danger:hover { background: #fee2e2; color: #ef4444; border-color: #ef4444; }
</style>
