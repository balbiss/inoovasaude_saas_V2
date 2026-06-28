<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'

const route = useRoute()
const slug  = route.params.slug

const API = import.meta.env.VITE_API_URL || 'http://localhost:3000'

// State
const loading      = ref(true)
const submitting   = ref(false)
const notFound     = ref(false)
const success      = ref(false)
const errorMsg     = ref('')
const successData  = ref(null)

const clinic       = ref(null)
const professionals = ref([])
const services      = ref([])

const step = ref(1) // 1=profissional+servico, 2=data+horario, 3=dados, 4=confirmação

// Step 1
const selectedProf    = ref(null)
const selectedService = ref(null)

// Step 2
const selectedDate  = ref('')
const selectedSlot  = ref('')
const loadingSlots  = ref(false)
const slots         = ref([])
const slotDuration  = ref(30)

// Step 3
const form = ref({
  name: '',
  cpf: '',
  phone: '',
  health_plan: '',
  consultation_type: ''
})

// Computed
const profScheduleSummary = (prof) => {
  if (!prof?.schedule) return ''
  const labels = { segunda: 'Seg', terca: 'Ter', quarta: 'Qua', quinta: 'Qui', sexta: 'Sex', sabado: 'Sáb', domingo: 'Dom' }
  return Object.entries(prof.schedule)
    .filter(([, v]) => v.active)
    .map(([k, v]) => `${labels[k]} ${v.start}-${v.end}`)
    .join(' | ')
}

const morningSlots = computed(() => slots.value.filter(s => parseInt(s) < 12))
const afternoonSlots = computed(() => slots.value.filter(s => parseInt(s) >= 12))

const minDate = computed(() => {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  return d.toISOString().split('T')[0]
})

const formattedDate = computed(() => {
  if (!selectedDate.value) return ''
  const [y, m, d] = selectedDate.value.split('-')
  return `${d}/${m}/${y}`
})

const cpfFormatted = computed(() => {
  const v = form.value.cpf.replace(/\D/g, '')
  return v.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4')
})

// Fetch clinic data
onMounted(async () => {
  try {
    const res = await axios.get(`${API}/public/booking/${slug}`)
    clinic.value       = res.data
    professionals.value = res.data.professionals
    services.value      = res.data.services
  } catch {
    notFound.value = true
  } finally {
    loading.value = false
  }
})

// Step 1 → 2
const selectProf = (prof) => {
  selectedProf.value    = prof
  selectedService.value = null
  selectedDate.value    = ''
  selectedSlot.value    = ''
  slots.value           = []
}

const goToStep2 = () => {
  if (!selectedProf.value) { errorMsg.value = 'Selecione um profissional.'; return }
  errorMsg.value = ''
  step.value = 2
}

// Fetch slots when date changes
const onDateChange = async () => {
  selectedSlot.value = ''
  slots.value = []
  if (!selectedDate.value || !selectedProf.value) return

  loadingSlots.value = true
  try {
    const res = await axios.get(`${API}/public/booking/${slug}/slots`, {
      params: { professional_id: selectedProf.value.id, date: selectedDate.value }
    })
    slots.value      = res.data.slots || []
    slotDuration.value = res.data.duration || 30
  } catch {
    slots.value = []
  } finally {
    loadingSlots.value = false
  }
}

// Step 2 → 3
const goToStep3 = () => {
  if (!selectedDate.value) { errorMsg.value = 'Selecione uma data.'; return }
  if (!selectedSlot.value) { errorMsg.value = 'Selecione um horário.'; return }
  errorMsg.value = ''
  step.value = 3
}

// CPF mask
const onCpfInput = (e) => {
  let v = e.target.value.replace(/\D/g, '').slice(0, 11)
  v = v.replace(/(\d{3})(\d)/, '$1.$2')
  v = v.replace(/(\d{3})\.(\d{3})(\d)/, '$1.$2.$3')
  v = v.replace(/(\d{3})\.(\d{3})\.(\d{3})(\d)/, '$1.$2.$3-$4')
  form.value.cpf = v
}

// Phone mask
const onPhoneInput = (e) => {
  let v = e.target.value.replace(/\D/g, '').slice(0, 11)
  if (v.length <= 10) v = v.replace(/(\d{2})(\d{4})(\d{0,4})/, '($1) $2-$3')
  else v = v.replace(/(\d{2})(\d{5})(\d{0,4})/, '($1) $2-$3')
  form.value.phone = v
}

// Step 3 → 4 (review)
const goToReview = () => {
  if (!form.value.name.trim()) { errorMsg.value = 'Informe seu nome completo.'; return }
  const rawCpf = form.value.cpf.replace(/\D/g, '')
  if (rawCpf.length !== 11) { errorMsg.value = 'CPF inválido.'; return }
  errorMsg.value = ''
  step.value = 4
}

// Submit
const submit = async () => {
  submitting.value = true
  errorMsg.value   = ''
  try {
    const res = await axios.post(`${API}/public/booking/${slug}/appointments`, {
      professional_id:  selectedProf.value.id,
      service_id:       selectedService.value?.id,
      appointment_date: selectedDate.value,
      start_time:       selectedSlot.value,
      name:             form.value.name,
      cpf:              form.value.cpf.replace(/\D/g, ''),
      phone:            form.value.phone.replace(/\D/g, ''),
      health_plan:      form.value.health_plan,
      consultation_type: form.value.consultation_type || selectedService.value?.name || 'Consulta'
    })
    successData.value = res.data.appointment
    success.value     = true
  } catch (err) {
    errorMsg.value = err.response?.data?.error || 'Erro ao realizar agendamento. Tente novamente.'
    step.value = 3
  } finally {
    submitting.value = false
  }
}

const restart = () => {
  step.value = 1
  selectedProf.value = null
  selectedService.value = null
  selectedDate.value = ''
  selectedSlot.value = ''
  slots.value = []
  form.value = { name: '', cpf: '', phone: '', health_plan: '', consultation_type: '' }
  success.value = false
  successData.value = null
  errorMsg.value = ''
}
</script>

<template>
  <div class="booking-page">
    <!-- Loading -->
    <div v-if="loading" class="center-screen">
      <div class="spinner"></div>
      <p>Carregando...</p>
    </div>

    <!-- Not found -->
    <div v-else-if="notFound" class="center-screen">
      <div class="not-found-icon">🏥</div>
      <h2>Página não encontrada</h2>
      <p>Este link de agendamento não existe ou está desativado.</p>
    </div>

    <!-- Success -->
    <div v-else-if="success" class="center-screen success-screen">
      <div class="success-icon">✅</div>
      <h2>Agendamento Confirmado!</h2>
      <div v-if="successData" class="success-card">
        <div class="success-row"><span>Profissional</span><strong>{{ successData.professional }}</strong></div>
        <div class="success-row" v-if="successData.service"><span>Serviço</span><strong>{{ successData.service }}</strong></div>
        <div class="success-row"><span>Data</span><strong>{{ successData.date }}</strong></div>
        <div class="success-row"><span>Horário</span><strong>{{ successData.time }}</strong></div>
      </div>
      <p class="success-note">Em breve você receberá uma confirmação no WhatsApp.</p>
      <button class="btn-primary" @click="restart">Fazer outro agendamento</button>
    </div>

    <!-- Main booking flow -->
    <template v-else>
      <!-- Header -->
      <div class="booking-header">
        <div class="clinic-logo">🏥</div>
        <h1>{{ clinic?.clinic_name }}</h1>
        <p>Agende sua consulta online, rápido e fácil</p>
      </div>

      <!-- Progress -->
      <div class="progress-bar">
        <div v-for="n in 4" :key="n"
          :class="['step-dot', n === step ? 'active' : n < step ? 'done' : '']">
          {{ n < step ? '✓' : n }}
        </div>
        <div class="step-label">
          {{ ['Profissional', 'Data e Horário', 'Seus Dados', 'Confirmação'][step - 1] }}
        </div>
      </div>

      <div class="booking-content">

        <!-- STEP 1: Profissional + Serviço -->
        <div v-if="step === 1">
          <h2 class="step-title">Escolha o profissional</h2>

          <div class="prof-grid">
            <div
              v-for="prof in professionals" :key="prof.id"
              :class="['prof-card', selectedProf?.id === prof.id ? 'selected' : '']"
              @click="selectProf(prof)">
              <div class="prof-avatar">{{ prof.name.charAt(0) }}</div>
              <div class="prof-info">
                <strong>{{ prof.name }}</strong>
                <span class="specialty">{{ prof.specialty }}</span>
                <span class="schedule-summary">{{ profScheduleSummary(prof) }}</span>
                <div class="plans" v-if="prof.accepted_plans?.length">
                  <span v-for="p in prof.accepted_plans" :key="p" class="plan-tag">{{ p }}</span>
                  <span v-if="prof.accepts_particular" class="plan-tag particular">Particular</span>
                </div>
              </div>
              <div v-if="selectedProf?.id === prof.id" class="check-mark">✓</div>
            </div>
          </div>

          <div v-if="selectedProf && services.length > 0" class="service-section">
            <h3>Tipo de consulta (opcional)</h3>
            <div class="service-grid">
              <div
                v-for="svc in services" :key="svc.id"
                :class="['service-card', selectedService?.id === svc.id ? 'selected' : '']"
                @click="selectedService = selectedService?.id === svc.id ? null : svc">
                <span class="svc-name">{{ svc.name }}</span>
                <span v-if="svc.price" class="svc-price">R$ {{ Number(svc.price).toFixed(2) }}</span>
              </div>
            </div>
          </div>

          <div v-if="errorMsg" class="error-msg">{{ errorMsg }}</div>
          <button class="btn-primary full" @click="goToStep2" :disabled="!selectedProf">
            Continuar
          </button>
        </div>

        <!-- STEP 2: Data + Horário -->
        <div v-if="step === 2">
          <h2 class="step-title">Escolha data e horário</h2>
          <div class="selected-prof-banner">
            <strong>{{ selectedProf?.name }}</strong>
            <span v-if="selectedService"> · {{ selectedService.name }}</span>
          </div>

          <div class="date-picker-section">
            <label>Data da consulta</label>
            <input type="date" v-model="selectedDate" :min="minDate" @change="onDateChange" class="date-input" />
          </div>

          <div v-if="selectedDate">
            <div v-if="loadingSlots" class="slots-loading">Buscando horários disponíveis...</div>
            <div v-else-if="slots.length === 0" class="no-slots">
              Nenhum horário disponível nesta data. Tente outra data.
            </div>
            <div v-else class="slots-section">
              <div v-if="morningSlots.length">
                <p class="period-label">🌅 Manhã</p>
                <div class="slots-grid">
                  <button
                    v-for="s in morningSlots" :key="s"
                    :class="['slot-btn', selectedSlot === s ? 'selected' : '']"
                    @click="selectedSlot = s">
                    {{ s }}
                  </button>
                </div>
              </div>
              <div v-if="afternoonSlots.length" style="margin-top:1.5rem">
                <p class="period-label">🌇 Tarde</p>
                <div class="slots-grid">
                  <button
                    v-for="s in afternoonSlots" :key="s"
                    :class="['slot-btn', selectedSlot === s ? 'selected' : '']"
                    @click="selectedSlot = s">
                    {{ s }}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div v-if="errorMsg" class="error-msg">{{ errorMsg }}</div>
          <div class="btn-row">
            <button class="btn-outline" @click="step = 1">Voltar</button>
            <button class="btn-primary" @click="goToStep3" :disabled="!selectedSlot">Continuar</button>
          </div>
        </div>

        <!-- STEP 3: Dados do paciente -->
        <div v-if="step === 3">
          <h2 class="step-title">Seus dados</h2>
          <div class="selected-prof-banner">
            <strong>{{ selectedProf?.name }}</strong>
            <span> · {{ formattedDate }} às {{ selectedSlot }}</span>
          </div>

          <div class="form-fields">
            <div class="field-group">
              <label>Nome completo *</label>
              <input type="text" v-model="form.name" placeholder="Como consta no documento" class="field-input" />
            </div>
            <div class="field-group">
              <label>CPF *</label>
              <input type="text" :value="form.cpf" @input="onCpfInput" placeholder="000.000.000-00" maxlength="14" class="field-input" />
            </div>
            <div class="field-group">
              <label>WhatsApp</label>
              <input type="tel" :value="form.phone" @input="onPhoneInput" placeholder="(00) 00000-0000" maxlength="15" class="field-input" />
            </div>
            <div class="field-group" v-if="selectedProf?.accepted_plans?.length || selectedProf?.accepts_particular">
              <label>Convênio / Plano</label>
              <select v-model="form.health_plan" class="field-input">
                <option value="">Selecione</option>
                <option v-for="p in selectedProf.accepted_plans" :key="p" :value="p">{{ p }}</option>
                <option v-if="selectedProf.accepts_particular" value="Particular">Particular</option>
              </select>
            </div>
          </div>

          <div v-if="errorMsg" class="error-msg">{{ errorMsg }}</div>
          <div class="btn-row">
            <button class="btn-outline" @click="step = 2">Voltar</button>
            <button class="btn-primary" @click="goToReview">Revisar</button>
          </div>
        </div>

        <!-- STEP 4: Confirmação -->
        <div v-if="step === 4">
          <h2 class="step-title">Confirme seu agendamento</h2>

          <div class="review-card">
            <div class="review-row">
              <span class="review-label">Profissional</span>
              <span class="review-value">{{ selectedProf?.name }}</span>
            </div>
            <div class="review-row" v-if="selectedService">
              <span class="review-label">Consulta</span>
              <span class="review-value">{{ selectedService.name }}</span>
            </div>
            <div class="review-row">
              <span class="review-label">Data</span>
              <span class="review-value">{{ formattedDate }}</span>
            </div>
            <div class="review-row">
              <span class="review-label">Horário</span>
              <span class="review-value">{{ selectedSlot }}</span>
            </div>
            <div class="review-divider"></div>
            <div class="review-row">
              <span class="review-label">Nome</span>
              <span class="review-value">{{ form.name }}</span>
            </div>
            <div class="review-row">
              <span class="review-label">CPF</span>
              <span class="review-value">{{ form.cpf }}</span>
            </div>
            <div class="review-row" v-if="form.phone">
              <span class="review-label">WhatsApp</span>
              <span class="review-value">{{ form.phone }}</span>
            </div>
            <div class="review-row" v-if="form.health_plan">
              <span class="review-label">Convênio</span>
              <span class="review-value">{{ form.health_plan }}</span>
            </div>
          </div>

          <div v-if="errorMsg" class="error-msg">{{ errorMsg }}</div>
          <div class="btn-row">
            <button class="btn-outline" @click="step = 3" :disabled="submitting">Editar</button>
            <button class="btn-primary" @click="submit" :disabled="submitting">
              {{ submitting ? 'Agendando...' : 'Confirmar Agendamento' }}
            </button>
          </div>
        </div>

      </div>

      <!-- Footer -->
      <div class="booking-footer">
        <p>{{ clinic?.clinic_name }} · Agendamento Online</p>
      </div>
    </template>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; }

.booking-page {
  min-height: 100vh;
  background: #f0fdf9;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  color: #1e293b;
}

.center-screen {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  text-align: center;
  padding: 2rem;
  gap: 1rem;

  h2 { font-size: 1.5rem; color: #0f172a; }
  p  { color: #64748b; }
}

.spinner {
  width: 40px; height: 40px;
  border: 3px solid #e2e8f0;
  border-top-color: #0d9488;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.not-found-icon { font-size: 4rem; }

.success-screen { gap: 1.5rem; }
.success-icon { font-size: 4rem; }
.success-card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  width: 100%;
  max-width: 360px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.08);
}
.success-row {
  display: flex;
  justify-content: space-between;
  padding: 0.5rem 0;
  border-bottom: 1px solid #f1f5f9;
  span { color: #64748b; font-size: 0.9rem; }
  strong { color: #0f172a; }
}
.success-note { color: #64748b; font-size: 0.9rem; }

/* Header */
.booking-header {
  background: linear-gradient(135deg, #0d9488, #0f766e);
  color: white;
  text-align: center;
  padding: 3rem 1.5rem 2rem;
  .clinic-logo { font-size: 3rem; margin-bottom: 0.5rem; }
  h1 { font-size: 1.75rem; font-weight: 700; margin: 0 0 0.5rem; }
  p  { opacity: 0.85; font-size: 1rem; margin: 0; }
}

/* Progress */
.progress-bar {
  background: white;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e2e8f0;
  position: sticky;
  top: 0;
  z-index: 10;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}
.step-dot {
  width: 28px; height: 28px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.8rem; font-weight: 600;
  background: #e2e8f0; color: #64748b;
  flex-shrink: 0;
  &.active { background: #0d9488; color: white; }
  &.done   { background: #dcfce7; color: #16a34a; }
}
.step-label { color: #0d9488; font-weight: 600; font-size: 0.95rem; margin-left: auto; }

/* Content */
.booking-content {
  max-width: 640px;
  margin: 0 auto;
  padding: 2rem 1.5rem;
}

.step-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #0f172a;
  margin: 0 0 1.5rem;
}

/* Professor cards */
.prof-grid { display: flex; flex-direction: column; gap: 1rem; margin-bottom: 2rem; }
.prof-card {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.25rem;
  cursor: pointer;
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  transition: border-color 0.2s, box-shadow 0.2s;
  position: relative;
  &:hover { border-color: #0d9488; box-shadow: 0 2px 8px rgba(13,148,136,0.1); }
  &.selected { border-color: #0d9488; background: #f0fdf9; }
}
.prof-avatar {
  width: 48px; height: 48px;
  border-radius: 50%;
  background: linear-gradient(135deg, #0d9488, #0f766e);
  color: white;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.25rem; font-weight: 700;
  flex-shrink: 0;
}
.prof-info {
  flex: 1;
  display: flex; flex-direction: column; gap: 0.25rem;
  strong { color: #0f172a; font-size: 1rem; }
}
.specialty { color: #0d9488; font-size: 0.85rem; font-weight: 500; }
.schedule-summary { color: #64748b; font-size: 0.8rem; }
.plans { display: flex; flex-wrap: wrap; gap: 0.35rem; margin-top: 0.25rem; }
.plan-tag {
  background: #f1f5f9; color: #475569;
  padding: 0.2rem 0.6rem;
  border-radius: 20px; font-size: 0.75rem;
  &.particular { background: #dcfce7; color: #16a34a; }
}
.check-mark {
  width: 24px; height: 24px;
  background: #0d9488; color: white;
  border-radius: 50%; display: flex; align-items: center; justify-content: center;
  font-size: 0.8rem; font-weight: 700; flex-shrink: 0;
}

/* Services */
.service-section { margin-bottom: 1.5rem; h3 { font-size: 1rem; color: #374151; margin: 0 0 0.75rem; } }
.service-grid { display: flex; flex-wrap: wrap; gap: 0.75rem; }
.service-card {
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  cursor: pointer;
  display: flex; flex-direction: column; gap: 0.2rem;
  transition: border-color 0.2s;
  &:hover { border-color: #0d9488; }
  &.selected { border-color: #0d9488; background: #f0fdf9; }
}
.svc-name { font-weight: 500; color: #1e293b; font-size: 0.9rem; }
.svc-price { color: #0d9488; font-size: 0.8rem; font-weight: 600; }

/* Step 2 */
.selected-prof-banner {
  background: #f0fdf9;
  border: 1px solid #99f6e4;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  font-size: 0.9rem;
  color: #0f766e;
  margin-bottom: 1.5rem;
}
.date-picker-section {
  margin-bottom: 1.5rem;
  label { display: block; font-weight: 500; color: #374151; margin-bottom: 0.5rem; font-size: 0.9rem; }
}
.date-input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 1rem;
  color: #1e293b;
  outline: none;
  &:focus { border-color: #0d9488; }
}
.slots-loading { color: #64748b; text-align: center; padding: 1.5rem; }
.no-slots {
  background: #fef9c3;
  border: 1px solid #fde047;
  border-radius: 8px;
  padding: 1rem;
  color: #854d0e;
  text-align: center;
  font-size: 0.9rem;
}
.slots-section { }
.period-label { font-weight: 600; color: #374151; font-size: 0.9rem; margin: 0 0 0.75rem; }
.slots-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.slot-btn {
  padding: 0.5rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  background: white;
  cursor: pointer;
  font-size: 0.9rem;
  font-weight: 500;
  color: #374151;
  transition: all 0.15s;
  &:hover { border-color: #0d9488; color: #0d9488; }
  &.selected { border-color: #0d9488; background: #0d9488; color: white; }
}

/* Step 3 */
.form-fields { display: flex; flex-direction: column; gap: 1.25rem; margin-bottom: 2rem; }
.field-group {
  label { display: block; font-weight: 500; color: #374151; margin-bottom: 0.4rem; font-size: 0.9rem; }
}
.field-input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 1rem;
  color: #1e293b;
  outline: none;
  background: white;
  &:focus { border-color: #0d9488; }
}

/* Step 4 */
.review-card {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.5rem;
  margin-bottom: 1.5rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}
.review-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.6rem 0;
  border-bottom: 1px solid #f1f5f9;
  &:last-child { border-bottom: none; }
}
.review-label { color: #64748b; font-size: 0.9rem; }
.review-value { color: #0f172a; font-weight: 500; font-size: 0.95rem; text-align: right; }
.review-divider { border-top: 2px dashed #e2e8f0; margin: 0.5rem 0; }

/* Buttons */
.btn-primary {
  background: #0d9488; color: white;
  border: none; border-radius: 8px;
  padding: 0.875rem 2rem;
  font-size: 1rem; font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
  &:hover:not(:disabled) { background: #0f766e; }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
  &.full { width: 100%; }
}
.btn-outline {
  background: white; color: #374151;
  border: 2px solid #e2e8f0; border-radius: 8px;
  padding: 0.875rem 1.5rem;
  font-size: 1rem; font-weight: 500;
  cursor: pointer;
  transition: border-color 0.2s;
  &:hover { border-color: #94a3b8; }
}
.btn-row {
  display: flex; gap: 1rem; justify-content: space-between;
  .btn-primary { flex: 1; }
}

.error-msg {
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 8px;
  padding: 0.75rem 1rem;
  color: #dc2626;
  font-size: 0.9rem;
  margin-bottom: 1rem;
}

/* Footer */
.booking-footer {
  text-align: center;
  padding: 2rem;
  color: #94a3b8;
  font-size: 0.85rem;
  border-top: 1px solid #e2e8f0;
  background: white;
  margin-top: 2rem;
}

@media (max-width: 480px) {
  .booking-header { padding: 2rem 1rem 1.5rem; h1 { font-size: 1.4rem; } }
  .booking-content { padding: 1.5rem 1rem; }
  .btn-row { flex-direction: column-reverse; }
  .slots-grid { gap: 0.4rem; }
  .slot-btn { padding: 0.5rem 0.75rem; font-size: 0.85rem; }
}
</style>
