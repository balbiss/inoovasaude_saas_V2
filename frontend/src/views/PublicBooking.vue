<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'

const route = useRoute()
const slug  = route.params.slug
const API   = import.meta.env.VITE_API_URL || 'http://localhost:3000'

const loading     = ref(true)
const submitting  = ref(false)
const notFound    = ref(false)
const success     = ref(false)
const errorMsg    = ref('')
const successData = ref(null)
const clinic      = ref(null)
const professionals = ref([])
const services      = ref([])
const step = ref(1)

const selectedProf    = ref(null)
const selectedService = ref(null)
const selectedDate    = ref('')
const selectedSlot    = ref('')
const loadingSlots    = ref(false)
const slots           = ref([])
const slotDuration    = ref(30)

const form = ref({ name: '', cpf: '', phone: '', health_plan: '', consultation_type: '' })

const specialtyIcon = (s = '') => {
  const map = {
    'médico': '🩺', 'medico': '🩺',
    'dentista': '🦷',
    'psicólogo': '🧠', 'psicologo': '🧠',
    'fisioterapeuta': '💪',
    'nutricionista': '🥗',
    'esteticista': '✨',
    'enfermeiro': '💉',
    'fonoaudiólogo': '🗣️', 'fonoaudiologo': '🗣️',
    'terapeuta': '🌿',
  }
  return map[s.toLowerCase()] || '👨‍⚕️'
}

const dayLabels = { segunda: 'Seg', terca: 'Ter', quarta: 'Qua', quinta: 'Qui', sexta: 'Sex', sabado: 'Sáb', domingo: 'Dom' }

const profSchedule = (prof) => {
  if (!prof?.schedule) return ''
  return Object.entries(prof.schedule)
    .filter(([, v]) => v.active)
    .map(([k, v]) => `${dayLabels[k]} ${v.start}–${v.end}`)
    .join('  ·  ')
}

const morningSlots   = computed(() => slots.value.filter(s => parseInt(s) < 12))
const afternoonSlots = computed(() => slots.value.filter(s => parseInt(s) >= 12))
const minDate = computed(() => {
  const d = new Date(); d.setDate(d.getDate() + 1)
  return d.toISOString().split('T')[0]
})
const formattedDate = computed(() => {
  if (!selectedDate.value) return ''
  const [, m, d] = selectedDate.value.split('-')
  const names = ['','Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro']
  return `${d} de ${names[+m]}`
})

onMounted(async () => {
  try {
    const res = await axios.get(`${API}/public/booking/${slug}`)
    clinic.value        = res.data
    professionals.value = res.data.professionals
    services.value      = res.data.services
  } catch { notFound.value = true }
  finally  { loading.value = false }
})

const selectProf = (prof) => {
  selectedProf.value    = prof
  selectedService.value = null
  selectedDate.value    = ''
  selectedSlot.value    = ''
  slots.value           = []
}

const goToStep2 = () => {
  if (!selectedProf.value) { errorMsg.value = 'Selecione um profissional.'; return }
  errorMsg.value = ''; step.value = 2
}

const onDateChange = async () => {
  selectedSlot.value = ''; slots.value = []
  if (!selectedDate.value || !selectedProf.value) return
  loadingSlots.value = true
  try {
    const res = await axios.get(`${API}/public/booking/${slug}/slots`, {
      params: { professional_id: selectedProf.value.id, date: selectedDate.value }
    })
    slots.value      = res.data.slots || []
    slotDuration.value = res.data.duration || 30
  } catch { slots.value = [] }
  finally   { loadingSlots.value = false }
}

const goToStep3 = () => {
  if (!selectedDate.value) { errorMsg.value = 'Selecione uma data.'; return }
  if (!selectedSlot.value) { errorMsg.value = 'Selecione um horário.'; return }
  errorMsg.value = ''; step.value = 3
}

const onCpfInput = (e) => {
  let v = e.target.value.replace(/\D/g, '').slice(0, 11)
  v = v.replace(/(\d{3})(\d)/, '$1.$2')
       .replace(/(\d{3})\.(\d{3})(\d)/, '$1.$2.$3')
       .replace(/(\d{3})\.(\d{3})\.(\d{3})(\d)/, '$1.$2.$3-$4')
  form.value.cpf = v
}
const onPhoneInput = (e) => {
  let v = e.target.value.replace(/\D/g, '').slice(0, 11)
  v = v.length <= 10
    ? v.replace(/(\d{2})(\d{4})(\d{0,4})/, '($1) $2-$3')
    : v.replace(/(\d{2})(\d{5})(\d{0,4})/, '($1) $2-$3')
  form.value.phone = v
}

const goToReview = () => {
  if (!form.value.name.trim()) { errorMsg.value = 'Informe seu nome completo.'; return }
  if (form.value.cpf.replace(/\D/g,'').length !== 11) { errorMsg.value = 'CPF inválido.'; return }
  errorMsg.value = ''; step.value = 4
}

const submit = async () => {
  submitting.value = true; errorMsg.value = ''
  try {
    const res = await axios.post(`${API}/public/booking/${slug}/appointments`, {
      professional_id:   selectedProf.value.id,
      service_id:        selectedService.value?.id,
      appointment_date:  selectedDate.value,
      start_time:        selectedSlot.value,
      name:              form.value.name,
      cpf:               form.value.cpf.replace(/\D/g,''),
      phone:             form.value.phone.replace(/\D/g,''),
      health_plan:       form.value.health_plan,
      consultation_type: form.value.consultation_type || selectedService.value?.name || 'Consulta'
    })
    successData.value = res.data.appointment; success.value = true
  } catch (err) {
    errorMsg.value = err.response?.data?.error || 'Erro ao realizar agendamento. Tente novamente.'
    step.value = 3
  } finally { submitting.value = false }
}

const restart = () => {
  step.value = 1; selectedProf.value = null; selectedService.value = null
  selectedDate.value = ''; selectedSlot.value = ''; slots.value = []
  form.value = { name: '', cpf: '', phone: '', health_plan: '', consultation_type: '' }
  success.value = false; successData.value = null; errorMsg.value = ''
}

const stepLabels = ['Profissional', 'Data & Horário', 'Seus dados', 'Confirmar']
</script>

<template>
  <div class="bp">

    <!-- Loading -->
    <div v-if="loading" class="bp-center">
      <div class="bp-spinner"></div>
      <p>Carregando...</p>
    </div>

    <!-- Not found -->
    <div v-else-if="notFound" class="bp-center">
      <span class="bp-big-icon">🏥</span>
      <h2>Página não encontrada</h2>
      <p>Este link de agendamento não existe ou está desativado.</p>
    </div>

    <!-- Success -->
    <div v-else-if="success" class="bp-center">
      <span class="bp-big-icon">✅</span>
      <h2 class="bp-success-title">Agendamento confirmado!</h2>
      <div v-if="successData" class="bp-confirm-card">
        <div class="bp-confirm-row">
          <span>👨‍⚕️ Profissional</span>
          <strong>{{ successData.professional }}</strong>
        </div>
        <div class="bp-confirm-row" v-if="successData.service">
          <span>🩺 Consulta</span>
          <strong>{{ successData.service }}</strong>
        </div>
        <div class="bp-confirm-row">
          <span>📅 Data</span>
          <strong>{{ successData.date }}</strong>
        </div>
        <div class="bp-confirm-row">
          <span>🕐 Horário</span>
          <strong>{{ successData.time }}</strong>
        </div>
      </div>
      <p class="bp-note">📲 Em breve você receberá a confirmação no WhatsApp.</p>
      <button class="bp-btn-primary" @click="restart">Fazer outro agendamento</button>
    </div>

    <!-- Main flow -->
    <template v-else>

      <!-- Header -->
      <div class="bp-header">
        <div class="bp-header-icon">🏥</div>
        <h1 class="bp-clinic-name">{{ clinic?.clinic_name }}</h1>
        <p class="bp-clinic-sub">Agendamento online · rápido e fácil</p>
      </div>

      <!-- Steps -->
      <div class="bp-steps">
        <div v-for="(label, i) in stepLabels" :key="i" class="bp-step-item">
          <div :class="['bp-step-num', i + 1 === step ? 'active' : i + 1 < step ? 'done' : '']">
            <span v-if="i + 1 < step">✓</span>
            <span v-else>{{ i + 1 }}</span>
          </div>
          <span :class="['bp-step-text', i + 1 === step ? 'active' : '']">{{ label }}</span>
        </div>
      </div>

      <div class="bp-body">

        <!-- ── STEP 1: Profissional ── -->
        <div v-if="step === 1">
          <h2 class="bp-section-title">👨‍⚕️ Escolha o profissional</h2>

          <div class="bp-prof-list">
            <div
              v-for="prof in professionals" :key="prof.id"
              :class="['bp-prof-card', selectedProf?.id === prof.id ? 'selected' : '']"
              @click="selectProf(prof)">
              <div class="bp-prof-avatar">{{ specialtyIcon(prof.specialty) }}</div>
              <div class="bp-prof-details">
                <p class="bp-prof-name">{{ prof.name }}</p>
                <p class="bp-prof-spec">{{ prof.specialty }}</p>
                <p class="bp-prof-sched">🕐 {{ profSchedule(prof) }}</p>
                <div v-if="prof.accepted_plans?.length || prof.accepts_particular" class="bp-plans">
                  <span v-for="p in prof.accepted_plans" :key="p" class="bp-plan-badge">{{ p }}</span>
                  <span v-if="prof.accepts_particular" class="bp-plan-badge particular">💳 Particular</span>
                </div>
              </div>
              <div v-if="selectedProf?.id === prof.id" class="bp-check">✓</div>
            </div>
          </div>

          <div v-if="selectedProf && services.length" class="bp-services">
            <h3 class="bp-sub-title">🩺 Tipo de consulta <span class="bp-optional">(opcional)</span></h3>
            <div class="bp-service-grid">
              <div
                v-for="svc in services" :key="svc.id"
                :class="['bp-svc-card', selectedService?.id === svc.id ? 'selected' : '']"
                @click="selectedService = selectedService?.id === svc.id ? null : svc">
                <span class="bp-svc-name">{{ svc.name }}</span>
                <span v-if="svc.price" class="bp-svc-price">R$ {{ Number(svc.price).toFixed(2) }}</span>
              </div>
            </div>
          </div>

          <div v-if="errorMsg" class="bp-error">⚠️ {{ errorMsg }}</div>
          <button class="bp-btn-primary full" @click="goToStep2" :disabled="!selectedProf">
            Continuar →
          </button>
        </div>

        <!-- ── STEP 2: Data + Horário ── -->
        <div v-if="step === 2">
          <div class="bp-banner">
            <span class="bp-banner-icon">{{ specialtyIcon(selectedProf?.specialty) }}</span>
            <div>
              <p class="bp-banner-name">{{ selectedProf?.name }}</p>
              <p class="bp-banner-sub" v-if="selectedService">{{ selectedService.name }}</p>
            </div>
          </div>

          <h2 class="bp-section-title">📅 Escolha a data</h2>
          <input type="date" v-model="selectedDate" :min="minDate" @change="onDateChange" class="bp-date-input" />

          <div v-if="selectedDate" class="bp-slots-wrap">
            <div v-if="loadingSlots" class="bp-loading-slots">
              <div class="bp-spinner small"></div> Buscando horários...
            </div>
            <div v-else-if="slots.length === 0" class="bp-no-slots">
              😕 Nenhum horário disponível nesta data.<br>Tente outra data.
            </div>
            <template v-else>
              <h3 class="bp-section-title" style="margin-top:1.5rem">🕐 Escolha o horário</h3>
              <div v-if="morningSlots.length">
                <p class="bp-period">🌅 Manhã</p>
                <div class="bp-slot-grid">
                  <button
                    v-for="s in morningSlots" :key="s"
                    :class="['bp-slot', selectedSlot === s ? 'selected' : '']"
                    @click="selectedSlot = s">{{ s }}</button>
                </div>
              </div>
              <div v-if="afternoonSlots.length" style="margin-top:1.25rem">
                <p class="bp-period">🌇 Tarde</p>
                <div class="bp-slot-grid">
                  <button
                    v-for="s in afternoonSlots" :key="s"
                    :class="['bp-slot', selectedSlot === s ? 'selected' : '']"
                    @click="selectedSlot = s">{{ s }}</button>
                </div>
              </div>
            </template>
          </div>

          <div v-if="errorMsg" class="bp-error">⚠️ {{ errorMsg }}</div>
          <div class="bp-btn-row">
            <button class="bp-btn-ghost" @click="step = 1">← Voltar</button>
            <button class="bp-btn-primary" @click="goToStep3" :disabled="!selectedSlot">Continuar →</button>
          </div>
        </div>

        <!-- ── STEP 3: Dados ── -->
        <div v-if="step === 3">
          <div class="bp-banner">
            <span class="bp-banner-icon">{{ specialtyIcon(selectedProf?.specialty) }}</span>
            <div>
              <p class="bp-banner-name">{{ selectedProf?.name }}</p>
              <p class="bp-banner-sub">{{ formattedDate }} · {{ selectedSlot }}</p>
            </div>
          </div>

          <h2 class="bp-section-title">📋 Seus dados</h2>

          <div class="bp-field">
            <label>👤 Nome completo *</label>
            <input v-model="form.name" type="text" placeholder="Como consta no documento" class="bp-input" />
          </div>
          <div class="bp-field">
            <label>🪪 CPF *</label>
            <input :value="form.cpf" @input="onCpfInput" type="text" placeholder="000.000.000-00" maxlength="14" class="bp-input" />
          </div>
          <div class="bp-field">
            <label>📱 WhatsApp</label>
            <input :value="form.phone" @input="onPhoneInput" type="tel" placeholder="(00) 00000-0000" maxlength="15" class="bp-input" />
          </div>
          <div class="bp-field" v-if="selectedProf?.accepted_plans?.length || selectedProf?.accepts_particular">
            <label>🏥 Convênio / Plano</label>
            <select v-model="form.health_plan" class="bp-input">
              <option value="">Selecione</option>
              <option v-for="p in selectedProf.accepted_plans" :key="p" :value="p">{{ p }}</option>
              <option v-if="selectedProf.accepts_particular" value="Particular">💳 Particular</option>
            </select>
          </div>

          <div v-if="errorMsg" class="bp-error">⚠️ {{ errorMsg }}</div>
          <div class="bp-btn-row">
            <button class="bp-btn-ghost" @click="step = 2">← Voltar</button>
            <button class="bp-btn-primary" @click="goToReview">Revisar →</button>
          </div>
        </div>

        <!-- ── STEP 4: Confirmar ── -->
        <div v-if="step === 4">
          <h2 class="bp-section-title">✅ Confirme seu agendamento</h2>

          <div class="bp-review">
            <div class="bp-review-section">
              <p class="bp-review-label">👨‍⚕️ Profissional</p>
              <p class="bp-review-value">{{ selectedProf?.name }}</p>
              <p class="bp-review-sub">{{ selectedProf?.specialty }}</p>
            </div>
            <div class="bp-review-section" v-if="selectedService">
              <p class="bp-review-label">🩺 Tipo de consulta</p>
              <p class="bp-review-value">{{ selectedService.name }}</p>
            </div>
            <div class="bp-review-row">
              <div class="bp-review-section">
                <p class="bp-review-label">📅 Data</p>
                <p class="bp-review-value">{{ formattedDate }}</p>
              </div>
              <div class="bp-review-section">
                <p class="bp-review-label">🕐 Horário</p>
                <p class="bp-review-value">{{ selectedSlot }}</p>
              </div>
            </div>
            <div class="bp-review-divider"></div>
            <div class="bp-review-section">
              <p class="bp-review-label">👤 Nome</p>
              <p class="bp-review-value">{{ form.name }}</p>
            </div>
            <div class="bp-review-row">
              <div class="bp-review-section">
                <p class="bp-review-label">🪪 CPF</p>
                <p class="bp-review-value">{{ form.cpf }}</p>
              </div>
              <div class="bp-review-section" v-if="form.phone">
                <p class="bp-review-label">📱 WhatsApp</p>
                <p class="bp-review-value">{{ form.phone }}</p>
              </div>
            </div>
            <div class="bp-review-section" v-if="form.health_plan">
              <p class="bp-review-label">🏥 Convênio</p>
              <p class="bp-review-value">{{ form.health_plan }}</p>
            </div>
          </div>

          <div v-if="errorMsg" class="bp-error">⚠️ {{ errorMsg }}</div>
          <div class="bp-btn-row">
            <button class="bp-btn-ghost" @click="step = 3" :disabled="submitting">← Editar</button>
            <button class="bp-btn-primary" @click="submit" :disabled="submitting">
              <span v-if="submitting">Agendando...</span>
              <span v-else>✅ Confirmar</span>
            </button>
          </div>
        </div>

      </div>

      <div class="bp-footer">
        <p>🏥 {{ clinic?.clinic_name }} · Agendamento Online</p>
      </div>
    </template>
  </div>
</template>

<style scoped>
* { box-sizing: border-box; margin: 0; padding: 0; }

.bp {
  min-height: 100dvh;
  background: #f0fdf9;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  color: #1e293b;
  display: flex;
  flex-direction: column;
}

/* ─── Center screens ─── */
.bp-center {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100dvh;
  padding: 2rem 1.5rem;
  text-align: center;
  gap: 1rem;
}
.bp-big-icon { font-size: 4rem; line-height: 1; }
.bp-center h2 { font-size: 1.5rem; color: #0f172a; font-weight: 700; }
.bp-center p  { color: #64748b; font-size: 0.95rem; }
.bp-success-title { color: #0d9488; }
.bp-confirm-card {
  width: 100%; max-width: 380px;
  background: white;
  border-radius: 16px;
  padding: 1.25rem;
  box-shadow: 0 4px 20px rgba(13,148,136,0.12);
  border: 1px solid #99f6e4;
}
.bp-confirm-row {
  display: flex; justify-content: space-between; align-items: center;
  padding: 0.65rem 0;
  border-bottom: 1px solid #f1f5f9;
  &:last-child { border-bottom: none; }
  span  { color: #64748b; font-size: 0.85rem; }
  strong { color: #0f172a; font-weight: 600; font-size: 0.9rem; }
}
.bp-note { color: #64748b; font-size: 0.875rem; }

/* ─── Header ─── */
.bp-header {
  background: linear-gradient(135deg, #0d9488 0%, #0f766e 100%);
  color: white;
  text-align: center;
  padding: 2.5rem 1.5rem 2rem;
}
.bp-header-icon { font-size: 2.75rem; margin-bottom: 0.5rem; }
.bp-clinic-name { font-size: 1.5rem; font-weight: 800; letter-spacing: -0.02em; }
.bp-clinic-sub  { font-size: 0.875rem; opacity: 0.85; margin-top: 0.25rem; }

/* ─── Steps ─── */
.bp-steps {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  background: white;
  padding: 1rem 0.5rem;
  border-bottom: 1px solid #e2e8f0;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
  position: sticky;
  top: 0;
  z-index: 20;
  overflow-x: auto;
}
.bp-step-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
  flex: 1;
  min-width: 60px;
}
.bp-step-num {
  width: 30px; height: 30px;
  border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.8rem; font-weight: 700;
  background: #e2e8f0; color: #94a3b8;
  transition: all 0.25s;
  &.active { background: #0d9488; color: white; box-shadow: 0 0 0 3px rgba(13,148,136,0.2); }
  &.done   { background: #dcfce7; color: #16a34a; }
}
.bp-step-text {
  font-size: 0.65rem;
  color: #94a3b8;
  font-weight: 500;
  white-space: nowrap;
  &.active { color: #0d9488; font-weight: 700; }
}

/* ─── Body ─── */
.bp-body {
  flex: 1;
  padding: 1.5rem 1rem 2rem;
  max-width: 560px;
  width: 100%;
  margin: 0 auto;
}

.bp-section-title {
  font-size: 1.1rem;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 1.25rem;
}
.bp-sub-title {
  font-size: 0.95rem;
  font-weight: 600;
  color: #374151;
  margin: 1.5rem 0 0.75rem;
}
.bp-optional { font-weight: 400; color: #94a3b8; font-size: 0.8rem; }

/* ─── Professional cards ─── */
.bp-prof-list { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.5rem; }
.bp-prof-card {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 14px;
  padding: 1rem;
  cursor: pointer;
  display: flex;
  align-items: flex-start;
  gap: 0.875rem;
  transition: all 0.2s;
  position: relative;
  &:active { transform: scale(0.99); }
  &:hover  { border-color: #5eead4; box-shadow: 0 4px 12px rgba(13,148,136,0.1); }
  &.selected { border-color: #0d9488; background: #f0fdf9; box-shadow: 0 4px 16px rgba(13,148,136,0.15); }
}
.bp-prof-avatar {
  width: 52px; height: 52px;
  border-radius: 14px;
  background: linear-gradient(135deg, #0d9488, #0f766e);
  display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(13,148,136,0.3);
}
.bp-prof-details { flex: 1; min-width: 0; }
.bp-prof-name { font-weight: 700; color: #0f172a; font-size: 0.975rem; margin-bottom: 0.15rem; }
.bp-prof-spec { color: #0d9488; font-size: 0.8rem; font-weight: 600; margin-bottom: 0.3rem; }
.bp-prof-sched { color: #64748b; font-size: 0.75rem; margin-bottom: 0.4rem; line-height: 1.4; }
.bp-plans { display: flex; flex-wrap: wrap; gap: 0.3rem; }
.bp-plan-badge {
  font-size: 0.7rem; font-weight: 500;
  padding: 0.2rem 0.55rem;
  border-radius: 20px;
  background: #f1f5f9; color: #475569;
  &.particular { background: #dcfce7; color: #16a34a; }
}
.bp-check {
  width: 26px; height: 26px;
  border-radius: 50%;
  background: #0d9488; color: white;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.8rem; font-weight: 700;
  flex-shrink: 0;
}

/* ─── Services ─── */
.bp-service-grid { display: flex; flex-wrap: wrap; gap: 0.6rem; }
.bp-svc-card {
  border: 2px solid #e2e8f0;
  border-radius: 10px;
  padding: 0.65rem 1rem;
  cursor: pointer;
  display: flex; flex-direction: column; gap: 0.15rem;
  transition: all 0.2s;
  &:hover   { border-color: #5eead4; }
  &.selected { border-color: #0d9488; background: #f0fdf9; }
}
.bp-svc-name  { font-weight: 600; color: #1e293b; font-size: 0.875rem; }
.bp-svc-price { color: #0d9488; font-size: 0.8rem; font-weight: 600; }

/* ─── Banner (step 2+) ─── */
.bp-banner {
  display: flex;
  align-items: center;
  gap: 0.875rem;
  background: #f0fdf9;
  border: 1px solid #99f6e4;
  border-radius: 12px;
  padding: 0.875rem 1rem;
  margin-bottom: 1.5rem;
}
.bp-banner-icon { font-size: 2rem; }
.bp-banner-name { font-weight: 700; color: #0f172a; font-size: 0.95rem; }
.bp-banner-sub  { color: #0d9488; font-size: 0.8rem; margin-top: 0.1rem; }

/* ─── Date input ─── */
.bp-date-input {
  width: 100%;
  padding: 0.875rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 10px;
  font-size: 1rem;
  color: #1e293b;
  background: white;
  outline: none;
  margin-bottom: 0.5rem;
  &:focus { border-color: #0d9488; }
}

/* ─── Slots ─── */
.bp-slots-wrap { margin-top: 0.5rem; }
.bp-loading-slots {
  display: flex; align-items: center; gap: 0.75rem;
  color: #64748b; padding: 1rem; font-size: 0.9rem;
}
.bp-no-slots {
  background: #fef9c3;
  border: 1px solid #fde047;
  border-radius: 10px;
  padding: 1rem;
  color: #854d0e;
  text-align: center;
  font-size: 0.875rem;
  line-height: 1.5;
  margin-top: 0.75rem;
}
.bp-period { font-size: 0.85rem; font-weight: 600; color: #374151; margin-bottom: 0.6rem; }
.bp-slot-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.bp-slot {
  padding: 0.55rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  background: white;
  cursor: pointer;
  font-size: 0.9rem;
  font-weight: 600;
  color: #374151;
  min-width: 68px;
  text-align: center;
  transition: all 0.15s;
  &:hover   { border-color: #0d9488; color: #0d9488; background: #f0fdf9; }
  &.selected { border-color: #0d9488; background: #0d9488; color: white; }
}

/* ─── Form fields ─── */
.bp-field {
  margin-bottom: 1.1rem;
  label { display: block; font-size: 0.85rem; font-weight: 600; color: #374151; margin-bottom: 0.4rem; }
}
.bp-input {
  width: 100%;
  padding: 0.875rem 1rem;
  border: 2px solid #e2e8f0;
  border-radius: 10px;
  font-size: 0.95rem;
  color: #1e293b;
  background: white;
  outline: none;
  transition: border-color 0.2s;
  &:focus { border-color: #0d9488; }
}

/* ─── Review ─── */
.bp-review {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  padding: 1.25rem;
  margin-bottom: 1.5rem;
  box-shadow: 0 2px 12px rgba(0,0,0,0.06);
}
.bp-review-section { margin-bottom: 0.75rem; }
.bp-review-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
}
.bp-review-label { font-size: 0.75rem; color: #94a3b8; font-weight: 500; margin-bottom: 0.1rem; }
.bp-review-value { font-size: 0.95rem; font-weight: 700; color: #0f172a; }
.bp-review-sub   { font-size: 0.8rem; color: #64748b; margin-top: 0.1rem; }
.bp-review-divider {
  border-top: 2px dashed #e2e8f0;
  margin: 0.75rem 0;
}

/* ─── Buttons ─── */
.bp-btn-primary {
  background: #0d9488; color: white;
  border: none; border-radius: 10px;
  padding: 0.9rem 1.5rem;
  font-size: 0.975rem; font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
  flex: 1;
  &:hover:not(:disabled) { background: #0f766e; transform: translateY(-1px); box-shadow: 0 4px 12px rgba(13,148,136,0.35); }
  &:disabled { opacity: 0.6; cursor: not-allowed; }
  &.full { width: 100%; margin-top: 1.5rem; }
}
.bp-btn-ghost {
  background: transparent; color: #64748b;
  border: 2px solid #e2e8f0; border-radius: 10px;
  padding: 0.9rem 1.25rem;
  font-size: 0.9rem; font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  &:hover { border-color: #94a3b8; color: #374151; }
}
.bp-btn-row {
  display: flex;
  gap: 0.75rem;
  margin-top: 1.5rem;
}

/* ─── Error ─── */
.bp-error {
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 10px;
  padding: 0.875rem 1rem;
  color: #dc2626;
  font-size: 0.875rem;
  margin-bottom: 1rem;
  line-height: 1.5;
}

/* ─── Spinner ─── */
.bp-spinner {
  width: 40px; height: 40px;
  border: 3px solid #e2e8f0;
  border-top-color: #0d9488;
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  &.small { width: 22px; height: 22px; border-width: 2px; }
}
@keyframes spin { to { transform: rotate(360deg); } }

/* ─── Footer ─── */
.bp-footer {
  text-align: center;
  padding: 1.5rem;
  color: #94a3b8;
  font-size: 0.8rem;
  border-top: 1px solid #e2e8f0;
  background: white;
}

/* ─── Mobile tweaks ─── */
@media (max-width: 480px) {
  .bp-header { padding: 2rem 1rem 1.5rem; }
  .bp-clinic-name { font-size: 1.3rem; }
  .bp-body { padding: 1.25rem 0.875rem 2rem; }
  .bp-step-text { display: none; }
  .bp-steps { gap: 0; padding: 0.75rem 0.5rem; }
  .bp-step-item { flex: 0; padding: 0 0.5rem; }
  .bp-btn-row { flex-direction: column; }
  .bp-btn-ghost { order: 2; }
  .bp-btn-primary { order: 1; }
  .bp-review-row { grid-template-columns: 1fr; }
  .bp-slot { min-width: 60px; font-size: 0.85rem; padding: 0.5rem 0.75rem; }
}
</style>
