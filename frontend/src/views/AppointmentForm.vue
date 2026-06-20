<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Save, CalendarDays } from 'lucide-vue-next'
import api from '../api'
import { useAppointmentsStore } from '../store/appointments'
import { storeToRefs } from 'pinia'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const appointmentsStore = useAppointmentsStore()
const { contacts, professionals, services } = storeToRefs(appointmentsStore)

const isEditing = computed(() => !!route.params.id)
const isLoading = ref(false)
const isSubmitting = ref(false)

const form = ref({
  contact_id: '',
  professional_id: '',
  service_id: '',
  appointment_date: '',
  start_time: '',
  end_time: '',
  status: 'agendado',
  consultation_type: 'presencial',
  notes: ''
})

const selectedProfessional = computed(() =>
  professionals.value.find(p => p.id === Number(form.value.professional_id))
)

const selectedService = computed(() =>
  services.value.find(s => s.id === Number(form.value.service_id))
)

const autoFillEndTime = () => {
  if (form.value.start_time && selectedService.value?.duration_minutes) {
    const [h, m] = form.value.start_time.split(':').map(Number)
    const totalMin = h * 60 + m + selectedService.value.duration_minutes
    const endH = String(Math.floor(totalMin / 60) % 24).padStart(2, '0')
    const endM = String(totalMin % 60).padStart(2, '0')
    form.value.end_time = `${endH}:${endM}`
  }
}

onMounted(async () => {
  await appointmentsStore.fetchMetaData()
  if (route.params.id) {
    isLoading.value = true
    try {
      const { data } = await api.get(`/appointments/${route.params.id}`)
      Object.assign(form.value, {
        contact_id: data.contact_id || '',
        professional_id: data.professional_id || '',
        service_id: data.service_id || '',
        appointment_date: data.appointment_date || '',
        start_time: data.start_time || '',
        end_time: data.end_time || '',
        status: data.status || 'agendado',
        consultation_type: data.consultation_type || 'presencial',
        notes: data.notes || ''
      })
    } catch {
      Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar consulta.', showConfirmButton: false, timer: 3000 })
      router.push('/agendamentos')
    } finally {
      isLoading.value = false
    }
  }
})

const save = async () => {
  if (!form.value.contact_id || !form.value.appointment_date || !form.value.start_time) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Preencha paciente, data e horário.', showConfirmButton: false, timer: 3000 })
    return
  }
  isSubmitting.value = true
  try {
    if (isEditing.value) {
      await api.put(`/appointments/${route.params.id}`, { appointment: form.value })
    } else {
      await api.post('/appointments', { appointment: form.value })
    }
    appointmentsStore.isLoadedOnce = false
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: isEditing.value ? 'Consulta atualizada!' : 'Consulta agendada! WhatsApp de confirmação será enviado em breve.', showConfirmButton: false, timer: 3500 })
    router.push('/agendamentos')
  } catch (e) {
    const msg = e.response?.data ? Object.values(e.response.data).flat().join(', ') : 'Erro ao salvar.'
    Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: msg, showConfirmButton: false, timer: 4000 })
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="form-page">
    <div class="form-header">
      <button class="btn-back" @click="router.push('/agendamentos')">
        <ArrowLeft class="icon-sm" /> Voltar
      </button>
      <h1>
        <CalendarDays class="header-icon" />
        {{ isEditing ? 'Editar Consulta' : 'Nova Consulta' }}
      </h1>
    </div>

    <div v-if="isLoading" class="loading-state">Carregando...</div>

    <div v-else class="form-layout">
      <!-- Preview card -->
      <div class="preview-panel">
        <div class="preview-card">
          <div class="preview-section">
            <h4>Profissional</h4>
            <p v-if="selectedProfessional">
              <strong>{{ selectedProfessional.name }}</strong><br>
              <span class="muted">{{ selectedProfessional.specialty }}</span>
            </p>
            <p v-else class="muted">Nenhum profissional selecionado</p>
          </div>
          <div class="preview-section">
            <h4>Serviço</h4>
            <p v-if="selectedService">
              <strong>{{ selectedService.name }}</strong><br>
              <span class="muted" v-if="selectedService.duration_minutes">Duração: {{ selectedService.duration_minutes }} min</span><br>
              <span class="muted" v-if="selectedService.price">R$ {{ parseFloat(selectedService.price).toFixed(2).replace('.', ',') }}</span>
            </p>
            <p v-else class="muted">Nenhum serviço selecionado</p>
          </div>
          <div class="preview-section" v-if="form.appointment_date && form.start_time">
            <h4>Quando</h4>
            <p>
              <strong>{{ new Date(form.appointment_date + 'T00:00:00').toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' }) }}</strong><br>
              <span class="muted">{{ form.start_time }}{{ form.end_time ? ' — ' + form.end_time : '' }}</span>
            </p>
          </div>
        </div>
      </div>

      <!-- Main form -->
      <div class="form-card">
        <div class="form-grid">
          <div class="form-group full">
            <label>Paciente *</label>
            <select v-model="form.contact_id">
              <option value="">Selecione o paciente...</option>
              <option v-for="c in contacts" :key="c.id" :value="c.id">
                {{ c.name }}{{ c.phone ? ` — ${c.phone}` : '' }}
              </option>
            </select>
          </div>

          <div class="form-group">
            <label>Profissional</label>
            <select v-model="form.professional_id">
              <option value="">Selecione o profissional...</option>
              <option v-for="p in professionals" :key="p.id" :value="p.id">
                {{ p.name }} ({{ p.specialty }})
              </option>
            </select>
          </div>

          <div class="form-group">
            <label>Serviço / Tipo de Consulta</label>
            <select v-model="form.service_id" @change="autoFillEndTime">
              <option value="">Selecione o serviço...</option>
              <option v-for="s in services" :key="s.id" :value="s.id">
                {{ s.name }}{{ s.duration_minutes ? ` (${s.duration_minutes}min)` : '' }}
              </option>
            </select>
          </div>

          <div class="form-group">
            <label>Data *</label>
            <input v-model="form.appointment_date" type="date" />
          </div>

          <div class="form-group">
            <label>Horário início *</label>
            <input v-model="form.start_time" type="time" @change="autoFillEndTime" />
          </div>

          <div class="form-group">
            <label>Horário fim</label>
            <input v-model="form.end_time" type="time" />
          </div>

          <div class="form-group">
            <label>Modalidade</label>
            <select v-model="form.consultation_type">
              <option value="presencial">Presencial</option>
              <option value="teleconsulta">Teleconsulta</option>
              <option value="domiciliar">Domiciliar</option>
            </select>
          </div>

          <div class="form-group">
            <label>Status</label>
            <select v-model="form.status">
              <option value="agendado">Agendado</option>
              <option value="confirmado">Confirmado</option>
              <option value="compareceu">Compareceu</option>
              <option value="nao_compareceu">Não compareceu</option>
              <option value="cancelado">Cancelado</option>
              <option value="retorno">Retorno</option>
            </select>
          </div>

          <div class="form-group full">
            <label>Observações</label>
            <textarea v-model="form.notes" rows="3" placeholder="Observações sobre a consulta..."></textarea>
          </div>
        </div>

        <div class="form-actions">
          <button class="btn-secondary" @click="router.push('/agendamentos')">Cancelar</button>
          <button class="btn-primary" @click="save" :disabled="isSubmitting">
            <Save class="icon-sm" />
            {{ isSubmitting ? 'Salvando...' : (isEditing ? 'Atualizar Consulta' : 'Agendar Consulta') }}
          </button>
        </div>
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
.loading-state { text-align: center; padding: 60px; color: var(--text-muted); }
.form-layout { display: flex; gap: 24px; align-items: flex-start; }
.preview-panel { width: 260px; flex-shrink: 0; }
.preview-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 20px; display: flex; flex-direction: column; gap: 16px; }
.preview-section h4 { font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted); margin: 0 0 6px; }
.preview-section p { font-size: 0.875rem; color: var(--text-main); margin: 0; line-height: 1.5; }
.muted { color: var(--text-muted); font-size: 0.8rem; }
.form-card { flex: 1; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 28px; }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.form-group { display: flex; flex-direction: column; gap: 6px; }
.form-group.full { grid-column: 1 / -1; }
.form-group label { font-size: 0.75rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
.form-group input, .form-group select, .form-group textarea { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 8px; padding: 8px 12px; color: var(--text-main); font-size: 0.875rem; width: 100%; }
.form-group input:focus, .form-group select:focus, .form-group textarea:focus { outline: none; border-color: var(--primary); }
.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--border-color); }
.btn-primary { display: flex; align-items: center; gap: 6px; background: var(--primary); color: #fff; border: none; border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer; }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-secondary { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; cursor: pointer; color: var(--text-main); }
.icon-sm { width: 16px; height: 16px; }
@media (max-width: 768px) {
  .form-layout { flex-direction: column; }
  .preview-panel { width: 100%; }
}
</style>
