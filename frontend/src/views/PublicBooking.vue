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

const form = ref({ name: '', cpf: '', phone: '', health_plan: '' })
const planOpen = ref(false)
const selectPlan = (p) => { form.value.health_plan = p; planOpen.value = false }
const planOptions = computed(() => {
  const opts = [...(selectedProf.value?.accepted_plans || [])]
  if (selectedProf.value?.accepts_particular) opts.push('Particular')
  return opts
})

const dayLabels = { segunda: 'Seg', terca: 'Ter', quarta: 'Qua', quinta: 'Qui', sexta: 'Sex', sabado: 'Sáb', domingo: 'Dom' }

const TITLES = new Set(['dr.', 'dra.', 'dr', 'dra', 'prof.', 'profa.', 'prof', 'profa'])
const profInitials = (name = '') =>
  name.split(' ')
    .filter(w => !TITLES.has(w.toLowerCase()))
    .slice(0, 2)
    .map(w => w[0])
    .join('')
    .toUpperCase()

const avatarColor = (specialty = '') => {
  const colors = {
    'médico': '#0d9488', 'medico': '#0d9488',
    'dentista': '#0891b2',
    'psicólogo': '#7c3aed', 'psicologo': '#7c3aed',
    'fisioterapeuta': '#059669',
    'nutricionista': '#d97706',
    'esteticista': '#db2777',
    'enfermeiro': '#2563eb',
    'fonoaudiólogo': '#0f766e',
    'terapeuta': '#065f46',
  }
  return colors[specialty.toLowerCase()] || '#0d9488'
}

const profScheduleSummary = (prof) => {
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
  const months = ['','Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez']
  return `${d} de ${months[+m]}`
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

const goStep = (n) => { errorMsg.value = ''; step.value = n }

const goToStep2 = () => {
  if (!selectedProf.value) { errorMsg.value = 'Selecione um profissional para continuar.'; return }
  goStep(2)
}

const onDateChange = async () => {
  selectedSlot.value = ''; slots.value = []
  if (!selectedDate.value || !selectedProf.value) return
  loadingSlots.value = true
  try {
    const res = await axios.get(`${API}/public/booking/${slug}/slots`, {
      params: { professional_id: selectedProf.value.id, date: selectedDate.value }
    })
    slots.value = res.data.slots || []; slotDuration.value = res.data.duration || 30
  } catch { slots.value = [] }
  finally { loadingSlots.value = false }
}

const goToStep3 = () => {
  if (!selectedDate.value) { errorMsg.value = 'Selecione uma data.'; return }
  if (!selectedSlot.value) { errorMsg.value = 'Selecione um horário.'; return }
  goStep(3)
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
  if (form.value.cpf.replace(/\D/g,'').length !== 11) { errorMsg.value = 'Informe um CPF válido (11 dígitos).'; return }
  goStep(4)
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
      consultation_type: selectedService.value?.name || 'Consulta'
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
  form.value = { name: '', cpf: '', phone: '', health_plan: '' }
  success.value = false; successData.value = null; errorMsg.value = ''
}

const stepLabels = ['Profissional', 'Data e Hora', 'Seus Dados', 'Confirmar']
</script>

<template>
  <div class="pb-root">

    <!-- ── Loading ── -->
    <div v-if="loading" class="pb-fullscreen">
      <div class="pb-spinner"></div>
      <p class="pb-muted">Carregando...</p>
    </div>

    <!-- ── Not found ── -->
    <div v-else-if="notFound" class="pb-fullscreen">
      <svg class="pb-icon-xl" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 9v4m0 4h.01M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/></svg>
      <h2>Página não encontrada</h2>
      <p class="pb-muted">Este link de agendamento não existe ou foi desativado.</p>
    </div>

    <!-- ── Success ── -->
    <div v-else-if="success" class="pb-fullscreen">
      <div class="pb-success-check">
        <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round"><polyline points="20 6 9 17 4 12"/></svg>
      </div>
      <h2 class="pb-success-title">Agendamento confirmado!</h2>
      <p class="pb-muted" style="margin-bottom:1.5rem">Em breve você receberá a confirmação no WhatsApp.</p>

      <div v-if="successData" class="pb-confirm-card">
        <div class="pb-confirm-header">
          <div class="pb-confirm-avatar" :style="{ background: avatarColor(selectedProf?.specialty || '') }">
            {{ profInitials(successData.professional) }}
          </div>
          <div>
            <p class="pb-confirm-name">{{ successData.professional }}</p>
            <p class="pb-confirm-spec" v-if="successData.service">{{ successData.service }}</p>
          </div>
        </div>
        <div class="pb-confirm-rows">
          <div class="pb-confirm-row">
            <span class="pb-confirm-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            </span>
            <div><p class="pb-confirm-label">Data</p><p class="pb-confirm-value">{{ successData.date }}</p></div>
          </div>
          <div class="pb-confirm-row">
            <span class="pb-confirm-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            </span>
            <div><p class="pb-confirm-label">Horário</p><p class="pb-confirm-value">{{ successData.time }}</p></div>
          </div>
        </div>
      </div>

      <button class="pb-btn-primary" @click="restart">Fazer novo agendamento</button>
    </div>

    <!-- ── Main flow ── -->
    <template v-else>

      <!-- Header -->
      <header class="pb-header">
        <div class="pb-header-logo">
          <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
          </svg>
        </div>
        <h1 class="pb-header-name">{{ clinic?.clinic_name }}</h1>
        <p class="pb-header-sub">Agendamento online</p>
      </header>

      <!-- Progress bar -->
      <nav class="pb-nav">
        <div v-for="(label, i) in stepLabels" :key="i" class="pb-nav-item">
          <div :class="['pb-nav-dot', i + 1 === step ? 'active' : i + 1 < step ? 'done' : '']">
            <svg v-if="i + 1 < step" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><polyline points="20 6 9 17 4 12"/></svg>
            <span v-else>{{ i + 1 }}</span>
          </div>
          <span :class="['pb-nav-label', i + 1 === step ? 'active' : '']">{{ label }}</span>
        </div>
        <!-- connector lines -->
        <div class="pb-nav-lines">
          <div v-for="i in 3" :key="i" :class="['pb-nav-line', i < step ? 'done' : '']"></div>
        </div>
      </nav>

      <!-- Content -->
      <main class="pb-main">

        <!-- ── Step 1: Profissional ── -->
        <section v-if="step === 1">
          <h2 class="pb-title">Escolha o profissional</h2>

          <div class="pb-prof-list">
            <button
              v-for="prof in professionals" :key="prof.id"
              :class="['pb-prof-card', selectedProf?.id === prof.id ? 'is-selected' : '']"
              @click="selectProf(prof)">
              <div class="pb-prof-avatar" :style="{ background: avatarColor(prof.specialty) }">
                {{ profInitials(prof.name) }}
              </div>
              <div class="pb-prof-body">
                <p class="pb-prof-name">{{ prof.name }}</p>
                <p class="pb-prof-spec">{{ prof.specialty }}</p>
                <p class="pb-prof-hours">{{ profScheduleSummary(prof) }}</p>
                <div v-if="prof.accepted_plans?.length || prof.accepts_particular" class="pb-tags">
                  <span v-for="p in prof.accepted_plans" :key="p" class="pb-tag">{{ p }}</span>
                  <span v-if="prof.accepts_particular" class="pb-tag pb-tag--green">Particular</span>
                </div>
              </div>
              <div :class="['pb-prof-radio', selectedProf?.id === prof.id ? 'checked' : '']">
                <svg v-if="selectedProf?.id === prof.id" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round"><polyline points="20 6 9 17 4 12"/></svg>
              </div>
            </button>
          </div>

          <!-- Services -->
          <div v-if="selectedProf && services.length" class="pb-services">
            <p class="pb-subtitle">Tipo de consulta <span class="pb-opt">— opcional</span></p>
            <div class="pb-svc-grid">
              <button
                v-for="svc in services" :key="svc.id"
                :class="['pb-svc', selectedService?.id === svc.id ? 'is-selected' : '']"
                @click="selectedService = selectedService?.id === svc.id ? null : svc">
                <span class="pb-svc-name">{{ svc.name }}</span>
                <span v-if="svc.price" class="pb-svc-price">R$ {{ Number(svc.price).toFixed(2) }}</span>
              </button>
            </div>
          </div>

          <p v-if="errorMsg" class="pb-error">{{ errorMsg }}</p>
          <button class="pb-btn-primary pb-btn-full" @click="goToStep2" :disabled="!selectedProf">
            Continuar
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
          </button>
        </section>

        <!-- ── Step 2: Data + Horário ── -->
        <section v-if="step === 2">
          <!-- Selected prof banner -->
          <div class="pb-banner">
            <div class="pb-banner-avatar" :style="{ background: avatarColor(selectedProf?.specialty || '') }">
              {{ profInitials(selectedProf?.name || '') }}
            </div>
            <div class="pb-banner-info">
              <p class="pb-banner-name">{{ selectedProf?.name }}</p>
              <p class="pb-banner-spec">{{ selectedProf?.specialty }}<span v-if="selectedService"> · {{ selectedService.name }}</span></p>
            </div>
            <button class="pb-banner-change" @click="goStep(1)">Alterar</button>
          </div>

          <h2 class="pb-title">Selecione a data</h2>
          <input type="date" v-model="selectedDate" :min="minDate" @change="onDateChange" class="pb-date" />

          <template v-if="selectedDate">
            <div v-if="loadingSlots" class="pb-loading">
              <div class="pb-spinner pb-spinner--sm"></div>
              <span>Verificando disponibilidade...</span>
            </div>
            <div v-else-if="slots.length === 0" class="pb-empty-slots">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
              <p>Nenhum horário disponível nesta data.</p>
              <span>Selecione outra data para continuar.</span>
            </div>
            <template v-else>
              <h2 class="pb-title" style="margin-top:1.75rem">Selecione o horário</h2>
              <div v-if="morningSlots.length" class="pb-slots-group">
                <p class="pb-slots-label">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  Manhã
                </p>
                <div class="pb-slots">
                  <button v-for="s in morningSlots" :key="s"
                    :class="['pb-slot', selectedSlot === s ? 'is-selected' : '']"
                    @click="selectedSlot = s">{{ s }}</button>
                </div>
              </div>
              <div v-if="afternoonSlots.length" class="pb-slots-group">
                <p class="pb-slots-label">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  Tarde
                </p>
                <div class="pb-slots">
                  <button v-for="s in afternoonSlots" :key="s"
                    :class="['pb-slot', selectedSlot === s ? 'is-selected' : '']"
                    @click="selectedSlot = s">{{ s }}</button>
                </div>
              </div>
            </template>
          </template>

          <p v-if="errorMsg" class="pb-error">{{ errorMsg }}</p>
          <div class="pb-actions">
            <button class="pb-btn-ghost" @click="goStep(1)">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
              Voltar
            </button>
            <button class="pb-btn-primary" @click="goToStep3" :disabled="!selectedSlot">
              Continuar
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
            </button>
          </div>
        </section>

        <!-- ── Step 3: Dados ── -->
        <section v-if="step === 3">
          <div class="pb-banner">
            <div class="pb-banner-avatar" :style="{ background: avatarColor(selectedProf?.specialty || '') }">
              {{ profInitials(selectedProf?.name || '') }}
            </div>
            <div class="pb-banner-info">
              <p class="pb-banner-name">{{ selectedProf?.name }}</p>
              <p class="pb-banner-spec">{{ formattedDate }} · {{ selectedSlot }}</p>
            </div>
          </div>

          <h2 class="pb-title">Seus dados</h2>

          <div class="pb-form">
            <label class="pb-label">
              Nome completo *
              <input v-model="form.name" type="text" placeholder="Como consta no documento" class="pb-input" autocomplete="name" />
            </label>
            <label class="pb-label">
              CPF *
              <input :value="form.cpf" @input="onCpfInput" type="text" placeholder="000.000.000-00" maxlength="14" class="pb-input" inputmode="numeric" />
            </label>
            <label class="pb-label">
              WhatsApp <span class="pb-opt">— opcional</span>
              <input :value="form.phone" @input="onPhoneInput" type="tel" placeholder="(00) 00000-0000" maxlength="15" class="pb-input" />
            </label>
            <div class="pb-label" v-if="planOptions.length">
              Convênio / Plano de saúde <span class="pb-opt">— opcional</span>
              <div class="pb-select-wrap" @mouseleave="planOpen = false">
                <button type="button" class="pb-custom-select pb-input" :class="{ open: planOpen }" @click="planOpen = !planOpen">
                  <span :style="{ color: form.health_plan ? '#1e293b' : '#94a3b8' }">{{ form.health_plan || 'Selecione' }}</span>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="6 9 12 15 18 9"/></svg>
                </button>
                <div v-if="planOpen" class="pb-select-dropdown">
                  <button type="button" class="pb-select-opt" :class="{ active: form.health_plan === '' }" @click="selectPlan('')">Selecione</button>
                  <button v-for="p in planOptions" :key="p" type="button" class="pb-select-opt" :class="{ active: form.health_plan === p }" @click="selectPlan(p)">{{ p }}</button>
                </div>
              </div>
            </div>
          </div>

          <p v-if="errorMsg" class="pb-error">{{ errorMsg }}</p>
          <div class="pb-actions">
            <button class="pb-btn-ghost" @click="goStep(2)">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
              Voltar
            </button>
            <button class="pb-btn-primary" @click="goToReview">
              Revisar
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
            </button>
          </div>
        </section>

        <!-- ── Step 4: Confirmar ── -->
        <section v-if="step === 4">
          <h2 class="pb-title">Confirme seu agendamento</h2>

          <div class="pb-review-card">
            <!-- Prof section -->
            <div class="pb-review-prof">
              <div class="pb-banner-avatar" :style="{ background: avatarColor(selectedProf?.specialty || '') }">
                {{ profInitials(selectedProf?.name || '') }}
              </div>
              <div>
                <p class="pb-review-prof-name">{{ selectedProf?.name }}</p>
                <p class="pb-review-prof-spec">{{ selectedProf?.specialty }}<span v-if="selectedService"> · {{ selectedService.name }}</span></p>
              </div>
            </div>
            <div class="pb-review-divider"></div>
            <!-- Date + time -->
            <div class="pb-review-row2">
              <div class="pb-review-field">
                <svg class="pb-review-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
                <div><p class="pb-review-label">Data</p><p class="pb-review-value">{{ formattedDate }}</p></div>
              </div>
              <div class="pb-review-field">
                <svg class="pb-review-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                <div><p class="pb-review-label">Horário</p><p class="pb-review-value">{{ selectedSlot }}</p></div>
              </div>
            </div>
            <div class="pb-review-divider"></div>
            <!-- Patient info -->
            <div class="pb-review-field">
              <svg class="pb-review-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
              <div><p class="pb-review-label">Nome</p><p class="pb-review-value">{{ form.name }}</p></div>
            </div>
            <div class="pb-review-row2">
              <div class="pb-review-field">
                <svg class="pb-review-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/></svg>
                <div><p class="pb-review-label">CPF</p><p class="pb-review-value">{{ form.cpf }}</p></div>
              </div>
              <div v-if="form.phone" class="pb-review-field">
                <svg class="pb-review-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 1.29h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L7.91 8.9a16 16 0 0 0 6.06 6.06l.92-.92a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 21.73 16.92z"/></svg>
                <div><p class="pb-review-label">WhatsApp</p><p class="pb-review-value">{{ form.phone }}</p></div>
              </div>
            </div>
            <div v-if="form.health_plan" class="pb-review-field">
              <svg class="pb-review-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>
              <div><p class="pb-review-label">Convênio</p><p class="pb-review-value">{{ form.health_plan }}</p></div>
            </div>
          </div>

          <p v-if="errorMsg" class="pb-error">{{ errorMsg }}</p>
          <div class="pb-actions">
            <button class="pb-btn-ghost" @click="goStep(3)" :disabled="submitting">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
              Editar
            </button>
            <button class="pb-btn-primary" @click="submit" :disabled="submitting">
              <div v-if="submitting" class="pb-spinner pb-spinner--sm pb-spinner--white"></div>
              <span>{{ submitting ? 'Agendando...' : 'Confirmar agendamento' }}</span>
            </button>
          </div>
        </section>

      </main>

      <footer class="pb-footer">{{ clinic?.clinic_name }}</footer>

    </template>
  </div>
</template>

<style lang="scss" scoped>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

.pb-root {
  position: fixed;
  inset: 0;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  overscroll-behavior: contain;
  background: #f8fafc;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
  color: #1e293b;
  display: flex;
  flex-direction: column;
}

/* ── Fullscreen states ── */
.pb-fullscreen {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  text-align: center;
  gap: 1rem;
  min-height: 100dvh;
}
.pb-icon-xl { width: 56px; height: 56px; color: #94a3b8; }
.pb-fullscreen h2 { font-size: 1.4rem; font-weight: 700; color: #0f172a; }
.pb-muted { color: #64748b; font-size: 0.9rem; line-height: 1.5; }
.pb-success-check {
  width: 72px; height: 72px;
  border-radius: 50%;
  background: #0d9488;
  display: flex; align-items: center; justify-content: center;
  box-shadow: 0 8px 24px rgba(13,148,136,0.35);
  svg { width: 36px; height: 36px; }
}
.pb-success-title { font-size: 1.5rem; font-weight: 800; color: #0d9488; }
.pb-confirm-card {
  width: 100%; max-width: 360px;
  background: white;
  border-radius: 16px;
  border: 1px solid #e2e8f0;
  overflow: hidden;
  box-shadow: 0 4px 24px rgba(0,0,0,0.08);
}
.pb-confirm-header {
  display: flex; align-items: center; gap: 0.875rem;
  padding: 1.25rem 1.25rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}
.pb-confirm-name { font-weight: 700; color: #0f172a; font-size: 0.975rem; }
.pb-confirm-spec { color: #64748b; font-size: 0.8rem; margin-top: 0.15rem; }
.pb-confirm-rows { padding: 0.5rem 1.25rem 1rem; display: flex; flex-direction: column; gap: 0.75rem; }
.pb-confirm-row {
  display: flex; align-items: center; gap: 0.75rem;
}
.pb-confirm-icon {
  width: 36px; height: 36px; border-radius: 8px;
  background: #f0fdf9; display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  svg { width: 18px; height: 18px; color: #0d9488; }
}
.pb-confirm-label { font-size: 0.75rem; color: #94a3b8; font-weight: 500; }
.pb-confirm-value { font-size: 0.95rem; font-weight: 700; color: #0f172a; }

/* ── Header ── */
.pb-header {
  background: linear-gradient(160deg, #0d9488 0%, #0f766e 100%);
  color: white;
  text-align: center;
  padding: 2.5rem 1.5rem 2rem;
}
.pb-header-logo {
  width: 52px; height: 52px;
  border-radius: 14px;
  background: rgba(255,255,255,0.2);
  display: flex; align-items: center; justify-content: center;
  margin: 0 auto 0.875rem;
  backdrop-filter: blur(8px);
  svg { width: 28px; height: 28px; }
}
.pb-header-name { font-size: 1.5rem; font-weight: 800; letter-spacing: -0.025em; }
.pb-header-sub  { font-size: 0.8rem; opacity: 0.75; margin-top: 0.25rem; letter-spacing: 0.04em; text-transform: uppercase; }

/* ── Nav / Steps ── */
.pb-nav {
  background: white;
  border-bottom: 1px solid #f1f5f9;
  padding: 1rem 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  position: sticky; top: 0; z-index: 30;
  box-shadow: 0 1px 6px rgba(0,0,0,0.06);
  position: relative;
}
.pb-nav-lines {
  position: absolute;
  top: 50%; left: 1.5rem; right: 1.5rem;
  display: flex;
  align-items: center;
  pointer-events: none;
  transform: translateY(-50%);
  padding: 0 calc(50% / 4);
  gap: calc((100% - 4 * 30px) / 3);
  justify-content: space-between;
}
.pb-nav-line {
  flex: 1;
  height: 2px;
  background: #e2e8f0;
  transition: background 0.3s;
  &.done { background: #0d9488; }
}
.pb-nav-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.3rem;
  z-index: 1;
}
.pb-nav-dot {
  width: 30px; height: 30px;
  border-radius: 50%;
  background: white;
  border: 2px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.75rem; font-weight: 700; color: #94a3b8;
  transition: all 0.25s;
  svg { width: 14px; height: 14px; }
  &.active { border-color: #0d9488; background: #0d9488; color: white; box-shadow: 0 0 0 4px rgba(13,148,136,0.15); }
  &.done   { border-color: #0d9488; background: #f0fdf9; color: #0d9488; }
}
.pb-nav-label {
  font-size: 0.62rem; font-weight: 500; color: #94a3b8; white-space: nowrap;
  &.active { color: #0d9488; font-weight: 700; }
}

/* ── Main ── */
.pb-main {
  flex: 1;
  padding: 1.75rem 1rem 3rem;
  max-width: 560px;
  width: 100%;
  margin: 0 auto;
}

.pb-title   { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin-bottom: 1.25rem; letter-spacing: -0.01em; }
.pb-subtitle { font-size: 0.9rem; font-weight: 600; color: #374151; margin-bottom: 0.75rem; }
.pb-opt     { font-weight: 400; color: #94a3b8; font-size: 0.8rem; }

/* ── Professional cards ── */
.pb-prof-list { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.75rem; }

.pb-prof-card {
  width: 100%;
  background: white;
  border: 1.5px solid #e2e8f0;
  border-radius: 14px;
  padding: 1rem;
  cursor: pointer;
  display: flex;
  align-items: flex-start;
  gap: 0.875rem;
  text-align: left;
  transition: all 0.18s;
  &:hover { border-color: #5eead4; box-shadow: 0 4px 16px rgba(13,148,136,0.1); }
  &.is-selected { border-color: #0d9488; background: #f0fdf9; box-shadow: 0 4px 16px rgba(13,148,136,0.14); }
}
.pb-prof-avatar {
  width: 48px; height: 48px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1rem; font-weight: 800; color: white;
  letter-spacing: -0.03em; flex-shrink: 0;
}
.pb-prof-body { flex: 1; min-width: 0; }
.pb-prof-name  { font-size: 0.95rem; font-weight: 700; color: #0f172a; }
.pb-prof-spec  { font-size: 0.78rem; font-weight: 600; color: #0d9488; margin: 0.15rem 0 0.4rem; }
.pb-prof-hours { font-size: 0.72rem; color: #94a3b8; line-height: 1.5; margin-bottom: 0.5rem; }
.pb-tags  { display: flex; flex-wrap: wrap; gap: 0.3rem; }
.pb-tag {
  font-size: 0.68rem; font-weight: 600;
  padding: 0.2rem 0.6rem;
  border-radius: 20px;
  background: #f1f5f9; color: #64748b;
  &--green { background: #dcfce7; color: #15803d; }
}
.pb-prof-radio {
  width: 22px; height: 22px; border-radius: 50%;
  border: 2px solid #e2e8f0;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; margin-top: 2px;
  transition: all 0.18s;
  &.checked { background: #0d9488; border-color: #0d9488; svg { width: 12px; height: 12px; } }
}

/* ── Services ── */
.pb-services { margin-bottom: 1.5rem; }
.pb-svc-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.pb-select-wrap { position: relative; margin-top: 0.4rem; }
.pb-custom-select {
  width: 100%; display: flex; justify-content: space-between; align-items: center;
  cursor: pointer; text-align: left;
  svg { width: 16px; height: 16px; color: #94a3b8; flex-shrink: 0; transition: transform 0.2s; }
  &.open { border-color: #0d9488; box-shadow: 0 0 0 3px rgba(13,148,136,0.1); svg { transform: rotate(180deg); } }
}
.pb-select-dropdown {
  position: absolute; top: calc(100% + 4px); left: 0; right: 0; z-index: 200;
  background: white; border: 1.5px solid #0d9488; border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.12); overflow: hidden;
  max-height: 220px; overflow-y: auto;
}
.pb-select-opt {
  width: 100%; text-align: left; padding: 0.75rem 1rem;
  background: none; border: none; border-bottom: 1px solid #f1f5f9;
  cursor: pointer; font-size: 0.9rem; color: #374151;
  &:last-child { border-bottom: none; }
  &:hover { background: #f0fdf9; color: #0d9488; }
  &.active { background: #f0fdf9; color: #0d9488; font-weight: 600; }
}
.pb-svc {
  border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: 0.6rem 1rem; cursor: pointer;
  display: flex; flex-direction: column; gap: 0.1rem;
  background: white; text-align: left;
  transition: all 0.18s;
  &:hover { border-color: #5eead4; }
  &.is-selected { border-color: #0d9488; background: #f0fdf9; }
}
.pb-svc-name  { font-size: 0.85rem; font-weight: 600; color: #1e293b; }
.pb-svc-price { font-size: 0.78rem; color: #0d9488; font-weight: 600; }

/* ── Banner ── */
.pb-banner {
  display: flex; align-items: center; gap: 0.875rem;
  background: white; border: 1px solid #e2e8f0;
  border-radius: 12px; padding: 0.875rem 1rem;
  margin-bottom: 1.5rem;
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}
.pb-banner-avatar {
  width: 42px; height: 42px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.85rem; font-weight: 800; color: white; flex-shrink: 0;
}
.pb-banner-info { flex: 1; min-width: 0; }
.pb-banner-name { font-weight: 700; color: #0f172a; font-size: 0.9rem; }
.pb-banner-spec { color: #64748b; font-size: 0.78rem; margin-top: 0.1rem; }
.pb-banner-change {
  font-size: 0.78rem; font-weight: 600; color: #0d9488;
  background: none; border: none; cursor: pointer; white-space: nowrap;
  padding: 0.25rem 0.5rem; border-radius: 6px;
  &:hover { background: #f0fdf9; }
}

/* ── Date ── */
.pb-date {
  width: 100%; padding: 0.875rem 1rem;
  border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: 1rem; color: #1e293b;
  background: white; outline: none;
  margin-bottom: 0.75rem;
  &:focus { border-color: #0d9488; box-shadow: 0 0 0 3px rgba(13,148,136,0.1); }
}

/* ── Slots ── */
.pb-loading {
  display: flex; align-items: center; gap: 0.75rem;
  color: #64748b; font-size: 0.875rem; padding: 0.75rem 0;
}
.pb-empty-slots {
  background: #fff7ed; border: 1px solid #fed7aa;
  border-radius: 10px; padding: 1.25rem;
  text-align: center; color: #92400e;
  svg { width: 28px; height: 28px; margin: 0 auto 0.5rem; display: block; }
  p { font-weight: 600; font-size: 0.9rem; }
  span { font-size: 0.8rem; color: #b45309; }
}
.pb-slots-group { margin-bottom: 1.25rem; }
.pb-slots-label {
  display: flex; align-items: center; gap: 0.4rem;
  font-size: 0.8rem; font-weight: 600; color: #64748b;
  margin-bottom: 0.6rem;
  svg { width: 16px; height: 16px; color: #94a3b8; }
}
.pb-slots { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.pb-slot {
  padding: 0.55rem 0.875rem; min-width: 64px;
  border: 1.5px solid #e2e8f0; border-radius: 8px;
  background: white; cursor: pointer;
  font-size: 0.875rem; font-weight: 600; color: #374151;
  text-align: center; transition: all 0.15s;
  &:hover { border-color: #0d9488; color: #0d9488; background: #f0fdf9; }
  &.is-selected { border-color: #0d9488; background: #0d9488; color: white; }
}

/* ── Form ── */
.pb-form { display: flex; flex-direction: column; gap: 1.1rem; margin-bottom: 0.5rem; }
.pb-label {
  display: flex; flex-direction: column; gap: 0.4rem;
  font-size: 0.82rem; font-weight: 600; color: #374151;
}
.pb-input {
  padding: 0.875rem 1rem;
  border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: 0.95rem; color: #1e293b;
  background: white; outline: none;
  width: 100%;
  transition: all 0.18s;
  &:focus { border-color: #0d9488; box-shadow: 0 0 0 3px rgba(13,148,136,0.1); }
  &::placeholder { color: #94a3b8; }
}
select.pb-input {
  appearance: none;
  -webkit-appearance: none;
  padding-right: 2.75rem;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%2394a3b8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.875rem center;
  cursor: pointer;
  &:focus { border-color: #0d9488; box-shadow: 0 0 0 3px rgba(13,148,136,0.1); }
}

/* ── Review card ── */
.pb-review-card {
  background: white; border: 1px solid #e2e8f0;
  border-radius: 16px; padding: 1.25rem;
  box-shadow: 0 2px 16px rgba(0,0,0,0.06);
  margin-bottom: 1.5rem;
  display: flex; flex-direction: column; gap: 0.875rem;
}
.pb-review-prof {
  display: flex; align-items: center; gap: 0.875rem;
}
.pb-review-prof-name { font-weight: 700; color: #0f172a; font-size: 0.95rem; }
.pb-review-prof-spec { color: #64748b; font-size: 0.8rem; margin-top: 0.15rem; }
.pb-review-divider { height: 1px; background: #f1f5f9; }
.pb-review-row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.pb-review-field { display: flex; align-items: flex-start; gap: 0.625rem; }
.pb-review-icon {
  width: 36px; height: 36px; border-radius: 8px;
  background: #f8fafc; display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  svg { width: 18px; height: 18px; color: #64748b; }
}
.pb-review-label { font-size: 0.72rem; color: #94a3b8; font-weight: 500; margin-bottom: 0.15rem; }
.pb-review-value { font-size: 0.9rem; font-weight: 700; color: #0f172a; }

/* ── Buttons ── */
.pb-btn-primary {
  display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem;
  background: #0d9488; color: white;
  border: none; border-radius: 10px;
  padding: 0.9rem 1.5rem;
  font-size: 0.925rem; font-weight: 700;
  cursor: pointer;
  transition: all 0.18s;
  svg { width: 16px; height: 16px; }
  &:hover:not(:disabled) { background: #0f766e; box-shadow: 0 4px 14px rgba(13,148,136,0.35); transform: translateY(-1px); }
  &:disabled { opacity: 0.55; cursor: not-allowed; transform: none; }
  &.pb-btn-full { width: 100%; margin-top: 1.5rem; }
}
.pb-actions .pb-btn-primary { flex: 1; }
.pb-btn-ghost {
  display: inline-flex; align-items: center; justify-content: center; gap: 0.4rem;
  background: white; color: #64748b;
  border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: 0.9rem 1.25rem;
  font-size: 0.875rem; font-weight: 600;
  cursor: pointer; white-space: nowrap;
  transition: all 0.18s;
  svg { width: 15px; height: 15px; }
  &:hover { border-color: #94a3b8; color: #374151; }
  &:disabled { opacity: 0.5; cursor: not-allowed; }
}
.pb-actions {
  display: flex; gap: 0.75rem; margin-top: 1.5rem;
}

/* ── Error ── */
.pb-error {
  background: #fef2f2; border: 1px solid #fecaca;
  border-radius: 10px; padding: 0.875rem 1rem;
  color: #dc2626; font-size: 0.875rem; line-height: 1.5;
  margin-bottom: 0.25rem;
}

/* ── Spinner ── */
.pb-spinner {
  width: 40px; height: 40px;
  border: 3px solid #e2e8f0; border-top-color: #0d9488;
  border-radius: 50%; animation: pb-spin 0.7s linear infinite;
  &--sm { width: 18px; height: 18px; border-width: 2px; }
  &--white { border-color: rgba(255,255,255,0.3); border-top-color: white; }
}
@keyframes pb-spin { to { transform: rotate(360deg); } }

/* ── Footer ── */
.pb-footer {
  text-align: center; padding: 1.25rem;
  color: #cbd5e1; font-size: 0.75rem;
  border-top: 1px solid #f1f5f9; background: white;
}

/* ── Mobile ── */
@media (max-width: 420px) {
  .pb-header { padding: 2rem 1.25rem 1.75rem; }
  .pb-header-name { font-size: 1.3rem; }
  .pb-nav-label { display: none; }
  .pb-nav { padding: 0.875rem 1.25rem; }
  .pb-main { padding: 1.5rem 0.875rem 3rem; }
  .pb-actions { flex-direction: column; .pb-btn-ghost { order: 2; } .pb-btn-primary { order: 1; } }
  .pb-review-row2 { grid-template-columns: 1fr; }
  .pb-slot { min-width: 58px; padding: 0.5rem 0.75rem; }
}
</style>
