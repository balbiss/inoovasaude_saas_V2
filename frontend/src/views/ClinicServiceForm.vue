<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Save, FlaskConical } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const isEdit = computed(() => !!route.params.id)

const CATEGORIES = [
  'Consulta', 'Retorno', 'Avaliação', 'Procedimento', 'Exame',
  'Terapia', 'Cirurgia', 'Tratamento Estético', 'Sessão', 'Outro'
]

const form = ref({
  name: '',
  description: '',
  duration_minutes: 30,
  price: '',
  category: '',
  status: 'active'
})
const isSaving = ref(false)

onMounted(async () => {
  if (isEdit.value) {
    try {
      const { data } = await api.get(`/services/${route.params.id}`)
      Object.assign(form.value, data)
    } catch {
      Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar serviço.', showConfirmButton: false, timer: 3000 })
      router.push('/servicos')
    }
  }
})

const save = async () => {
  if (!form.value.name) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Nome é obrigatório.', showConfirmButton: false, timer: 3000 })
    return
  }
  isSaving.value = true
  try {
    if (isEdit.value) {
      await api.put(`/services/${route.params.id}`, { service: form.value })
    } else {
      await api.post('/services', { service: form.value })
    }
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: isEdit.value ? 'Serviço atualizado!' : 'Serviço cadastrado!', showConfirmButton: false, timer: 2500 })
    router.push('/servicos')
  } catch (e) {
    const msg = e.response?.data ? Object.values(e.response.data).flat().join(', ') : 'Erro ao salvar.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 4000 })
  } finally {
    isSaving.value = false
  }
}
</script>

<template>
  <div class="form-page">
    <div class="form-header">
      <button class="btn-back" @click="router.push('/servicos')">
        <ArrowLeft class="icon-sm" /> Voltar
      </button>
      <h1>
        <FlaskConical class="header-icon" />
        {{ isEdit ? 'Editar Serviço' : 'Novo Serviço' }}
      </h1>
    </div>

    <div class="form-card">
      <div class="form-grid">
        <div class="form-group full">
          <label>Nome do Serviço *</label>
          <input v-model="form.name" type="text" placeholder="Ex: Consulta médica, Sessão de fisioterapia..." />
        </div>

        <div class="form-group">
          <label>Categoria</label>
          <select v-model="form.category">
            <option value="">Selecione...</option>
            <option v-for="c in CATEGORIES" :key="c" :value="c">{{ c }}</option>
          </select>
        </div>

        <div class="form-group">
          <label>Status</label>
          <select v-model="form.status">
            <option value="active">Ativo</option>
            <option value="inactive">Inativo</option>
          </select>
        </div>

        <div class="form-group">
          <label>Duração (minutos)</label>
          <input v-model.number="form.duration_minutes" type="number" min="5" step="5" placeholder="30" />
        </div>

        <div class="form-group">
          <label>Preço (R$)</label>
          <input v-model="form.price" type="number" step="0.01" min="0" placeholder="150.00" />
        </div>

        <div class="form-group full">
          <label>Descrição</label>
          <textarea v-model="form.description" rows="3" placeholder="Descreva o serviço..."></textarea>
        </div>
      </div>

      <div class="form-actions">
        <button class="btn-secondary" @click="router.push('/servicos')">Cancelar</button>
        <button class="btn-primary" @click="save" :disabled="isSaving">
          <Save class="icon-sm" />
          {{ isSaving ? 'Salvando...' : 'Salvar Serviço' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.form-page { padding: 24px; }
.form-header { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; }
.form-header h1 { display: flex; align-items: center; gap: 8px; font-size: 1.4rem; font-weight: 700; color: var(--text-main); }
.header-icon { width: 24px; height: 24px; color: var(--primary); }
.btn-back { display: flex; align-items: center; gap: 4px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 12px; font-size: 0.85rem; cursor: pointer; color: var(--text-main); }
.form-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 28px; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.form-group { display: flex; flex-direction: column; gap: 6px; }
.form-group.full { grid-column: 1 / -1; }
.form-group label { font-size: 0.8rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
.form-group input, .form-group select, .form-group textarea { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 8px; padding: 8px 12px; color: var(--text-main); font-size: 0.9rem; width: 100%; }
.form-group input:focus, .form-group select:focus, .form-group textarea:focus { outline: none; border-color: var(--primary); }
.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--border-color); }
.btn-primary { display: flex; align-items: center; gap: 6px; background: var(--primary); color: #fff; border: none; border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer; }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-secondary { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; cursor: pointer; color: var(--text-main); }
.icon-sm { width: 16px; height: 16px; }
</style>
