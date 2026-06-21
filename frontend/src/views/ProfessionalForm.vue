<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ArrowLeft, Save, Stethoscope, Calendar, Clock, X, Plus, ShieldCheck } from 'lucide-vue-next'
import api from '../api'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const isEdit = computed(() => !!route.params.id)

const HEALTH_PLANS = [
  'Unimed', 'Bradesco Saúde', 'Amil', 'SulAmérica', 'Porto Seguro Saúde',
  'Hapvida', 'NotreDame Intermédica', 'Prevent Senior', 'São Francisco Saúde',
  'Golden Cross', 'Cassi', 'Geap', 'Assefaz', 'Fusex', 'Postal Saúde',
  'Mediservice', 'Greenline', 'Omint', 'Allianz Saúde', 'Outro convênio',
]

const SPECIALTIES = [
  'Médico', 'Dentista', 'Psicólogo', 'Fisioterapeuta', 'Nutricionista',
  'Esteticista', 'Enfermeiro', 'Fonoaudiólogo', 'Terapeuta', 'Outro'
]

const DAYS = [
  { key: 'segunda', label: 'Segunda' },
  { key: 'terca',   label: 'Terça' },
  { key: 'quarta',  label: 'Quarta' },
  { key: 'quinta',  label: 'Quinta' },
  { key: 'sexta',   label: 'Sexta' },
  { key: 'sabado',  label: 'Sábado' },
  { key: 'domingo', label: 'Domingo' },
]

const DEFAULT_SCHEDULE = () => ({
  segunda: { active: true,  start: '08:00', end: '18:00' },
  terca:   { active: true,  start: '08:00', end: '18:00' },
  quarta:  { active: true,  start: '08:00', end: '18:00' },
  quinta:  { active: true,  start: '08:00', end: '18:00' },
  sexta:   { active: true,  start: '08:00', end: '17:00' },
  sabado:  { active: false, start: '08:00', end: '12:00' },
  domingo: { active: false, start: '08:00', end: '12:00' },
})

const form = ref({
  name: '',
  specialty: '',
  council_number: '',
  phone: '',
  email: '',
  bio: '',
  status: 'active',
  consultation_duration: 30,
  schedule: DEFAULT_SCHEDULE(),
  lunch_break: { active: true, start: '12:00', end: '13:00' },
  blocked_dates: [],
  accepted_plans: [],
  accepts_particular: true,
})

const newBlockedDate = ref('')
const isSaving = ref(false)

onMounted(async () => {
  if (isEdit.value) {
    try {
      const { data } = await api.get(`/professionals/${route.params.id}`)
      form.value = {
        ...form.value,
        ...data,
        schedule: data.schedule || DEFAULT_SCHEDULE(),
        lunch_break: data.lunch_break || { active: true, start: '12:00', end: '13:00' },
        blocked_dates: data.blocked_dates || [],
        accepted_plans: data.accepted_plans || [],
        accepts_particular: data.accepts_particular !== false,
      }
    } catch {
      Swal.fire({ toast: true, position: 'top-end', icon: 'error', title: 'Erro ao carregar profissional.', showConfirmButton: false, timer: 3000 })
      router.push('/profissionais')
    }
  }
})

const addBlockedDate = () => {
  const d = newBlockedDate.value
  if (!d) return
  if (!form.value.blocked_dates.includes(d)) {
    form.value.blocked_dates.push(d)
    form.value.blocked_dates.sort()
  }
  newBlockedDate.value = ''
}

const removeBlockedDate = (d) => {
  form.value.blocked_dates = form.value.blocked_dates.filter(x => x !== d)
}

const formatBlockedDate = (d) => {
  const [y, m, day] = d.split('-')
  return `${day}/${m}/${y}`
}

const save = async () => {
  if (!form.value.name || !form.value.specialty) {
    Swal.fire({ toast: true, position: 'top-end', icon: 'warning', title: 'Nome e especialidade são obrigatórios.', showConfirmButton: false, timer: 3000 })
    return
  }
  isSaving.value = true
  try {
    if (isEdit.value) {
      await api.put(`/professionals/${route.params.id}`, { professional: form.value })
    } else {
      await api.post('/professionals', { professional: form.value })
    }
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: isEdit.value ? 'Profissional atualizado!' : 'Profissional cadastrado!', showConfirmButton: false, timer: 2500 })
    router.push('/profissionais')
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
      <button class="btn-back" @click="router.push('/profissionais')">
        <ArrowLeft class="icon-sm" /> Voltar
      </button>
      <h1>
        <Stethoscope class="header-icon" />
        {{ isEdit ? 'Editar Profissional' : 'Novo Profissional' }}
      </h1>
    </div>

    <!-- Dados do profissional -->
    <div class="form-card">
      <div class="section-title">Dados do Profissional</div>
      <div class="form-grid">
        <div class="form-group full">
          <label>Nome completo *</label>
          <input v-model="form.name" type="text" placeholder="Dr. João Silva" />
        </div>

        <div class="form-group">
          <label>Especialidade *</label>
          <select v-model="form.specialty">
            <option value="">Selecione...</option>
            <option v-for="s in SPECIALTIES" :key="s" :value="s">{{ s }}</option>
          </select>
        </div>

        <div class="form-group">
          <label>Número do Conselho (CRM/CRO/CRP/CRN)</label>
          <input v-model="form.council_number" type="text" placeholder="CRM-SP 12345" />
        </div>

        <div class="form-group">
          <label>Telefone</label>
          <input v-model="form.phone" type="tel" placeholder="(11) 99999-9999" />
        </div>

        <div class="form-group">
          <label>E-mail</label>
          <input v-model="form.email" type="email" placeholder="dr@clinica.com" />
        </div>

        <div class="form-group">
          <label>Status</label>
          <select v-model="form.status">
            <option value="active">Ativo</option>
            <option value="inactive">Inativo</option>
          </select>
        </div>

        <div class="form-group full">
          <label>Biografia / Formação</label>
          <textarea v-model="form.bio" rows="3" placeholder="Formação, especializações, experiência..."></textarea>
        </div>
      </div>
    </div>

    <!-- Configurações de Agenda -->
    <div class="form-card mt">
      <div class="section-title"><Calendar class="section-icon" /> Configurações de Agenda</div>

      <!-- Duração da consulta -->
      <div class="agenda-row">
        <div class="form-group" style="max-width:220px">
          <label>Duração da consulta</label>
          <div class="input-addon">
            <input v-model.number="form.consultation_duration" type="number" min="5" max="240" step="5" />
            <span class="addon">min</span>
          </div>
        </div>
      </div>

      <!-- Horário de Almoço -->
      <div class="lunch-row">
        <label class="toggle-label">
          <input type="checkbox" v-model="form.lunch_break.active" class="toggle-check" />
          <span class="toggle-track"></span>
          <span class="toggle-text">Intervalo de almoço</span>
        </label>
        <template v-if="form.lunch_break.active">
          <div class="time-pair">
            <span class="time-label">Das</span>
            <input type="time" v-model="form.lunch_break.start" class="time-input" />
            <span class="time-label">às</span>
            <input type="time" v-model="form.lunch_break.end" class="time-input" />
          </div>
        </template>
      </div>

      <!-- Dias da semana -->
      <div class="days-table">
        <div class="days-header">
          <span>Dia</span>
          <span>Atende</span>
          <span>Início</span>
          <span>Término</span>
        </div>
        <div v-for="day in DAYS" :key="day.key" class="day-row" :class="{ inactive: !form.schedule[day.key]?.active }">
          <span class="day-name">{{ day.label }}</span>
          <label class="toggle-label small">
            <input type="checkbox" v-model="form.schedule[day.key].active" class="toggle-check" />
            <span class="toggle-track"></span>
          </label>
          <input
            type="time"
            v-model="form.schedule[day.key].start"
            class="time-input"
            :disabled="!form.schedule[day.key]?.active"
          />
          <input
            type="time"
            v-model="form.schedule[day.key].end"
            class="time-input"
            :disabled="!form.schedule[day.key]?.active"
          />
        </div>
      </div>
    </div>

    <!-- Convênios -->
    <div class="form-card mt">
      <div class="section-title"><ShieldCheck class="section-icon" /> Convênios e Formas de Pagamento</div>

      <label class="toggle-label" style="margin-bottom:16px">
        <input type="checkbox" v-model="form.accepts_particular" class="toggle-check" />
        <span class="toggle-track"></span>
        <span class="toggle-text">Aceita consulta particular</span>
      </label>

      <div class="plans-label">Convênios aceitos</div>
      <div class="plans-grid">
        <label v-for="plan in HEALTH_PLANS" :key="plan" class="plan-check">
          <input
            type="checkbox"
            :value="plan"
            v-model="form.accepted_plans"
          />
          <span class="plan-name">{{ plan }}</span>
        </label>
      </div>
    </div>

    <!-- Datas Bloqueadas -->
    <div class="form-card mt">
      <div class="section-title"><Clock class="section-icon" /> Datas Bloqueadas / Folgas</div>
      <p class="section-desc">Férias, feriados, afastamentos — o profissional não atende nessas datas.</p>

      <div class="blocked-add">
        <input type="date" v-model="newBlockedDate" class="date-input" />
        <button class="btn-add-date" @click="addBlockedDate">
          <Plus class="icon-sm" /> Adicionar data
        </button>
      </div>

      <div class="blocked-list">
        <span v-if="form.blocked_dates.length === 0" class="no-dates">Nenhuma data bloqueada.</span>
        <div v-for="d in form.blocked_dates" :key="d" class="blocked-chip">
          <span>{{ formatBlockedDate(d) }}</span>
          <button @click="removeBlockedDate(d)" class="chip-remove"><X :size="12" /></button>
        </div>
      </div>
    </div>

    <div class="form-actions">
      <button class="btn-secondary" @click="router.push('/profissionais')">Cancelar</button>
      <button class="btn-primary" @click="save" :disabled="isSaving">
        <Save class="icon-sm" />
        {{ isSaving ? 'Salvando...' : 'Salvar Profissional' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.form-page { padding: 24px; display: flex; flex-direction: column; gap: 0; }
.form-header { display: flex; align-items: center; gap: 16px; margin-bottom: 20px; }
.form-header h1 { display: flex; align-items: center; gap: 8px; font-size: 1.4rem; font-weight: 700; color: var(--text-main); }
.header-icon { width: 24px; height: 24px; color: var(--primary); }
.btn-back { display: flex; align-items: center; gap: 4px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 12px; font-size: 0.85rem; cursor: pointer; color: var(--text-main); }

.form-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 12px; padding: 24px; }
.form-card.mt { margin-top: 16px; }

.section-title { display: flex; align-items: center; gap: 8px; font-size: 0.95rem; font-weight: 700; color: var(--text-main); margin-bottom: 20px; padding-bottom: 12px; border-bottom: 1px solid var(--border-color); }
.section-icon { width: 18px; height: 18px; color: var(--primary); }
.section-desc { font-size: 0.83rem; color: var(--text-muted); margin-top: -12px; margin-bottom: 16px; }

.form-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; }
.form-group { display: flex; flex-direction: column; gap: 6px; }
.form-group.full { grid-column: 1 / -1; }
.form-group label { font-size: 0.78rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
.form-group input, .form-group select, .form-group textarea { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 8px; padding: 8px 12px; color: var(--text-main); font-size: 0.9rem; width: 100%; box-sizing: border-box; }
.form-group input:focus, .form-group select:focus, .form-group textarea:focus { outline: none; border-color: var(--primary); }

/* Duração */
.agenda-row { margin-bottom: 20px; }
.input-addon { display: flex; align-items: center; }
.input-addon input { border-radius: 8px 0 0 8px; border-right: none; }
.addon { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-left: none; border-radius: 0 8px 8px 0; padding: 8px 12px; font-size: 0.85rem; color: var(--text-muted); white-space: nowrap; }

/* Toggle switch */
.toggle-label { display: flex; align-items: center; gap: 10px; cursor: pointer; user-select: none; }
.toggle-label.small { gap: 0; }
.toggle-check { display: none; }
.toggle-track {
  width: 36px; height: 20px; background: var(--border-color); border-radius: 10px; position: relative; transition: background 0.2s; flex-shrink: 0;
}
.toggle-track::after {
  content: ''; position: absolute; top: 3px; left: 3px; width: 14px; height: 14px;
  background: white; border-radius: 50%; transition: left 0.2s;
}
.toggle-check:checked + .toggle-track { background: var(--primary); }
.toggle-check:checked + .toggle-track::after { left: 19px; }
.toggle-text { font-size: 0.9rem; color: var(--text-main); font-weight: 500; }

/* Almoço */
.lunch-row { display: flex; align-items: center; gap: 20px; flex-wrap: wrap; margin-bottom: 24px; padding: 14px 16px; background: var(--bg-primary); border-radius: 10px; border: 1px solid var(--border-color); }
.time-pair { display: flex; align-items: center; gap: 8px; }
.time-label { font-size: 0.85rem; color: var(--text-muted); }
.time-input { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 10px; color: var(--text-main); font-size: 0.88rem; }
.time-input:disabled { opacity: 0.4; cursor: not-allowed; }
.time-input:focus { outline: none; border-color: var(--primary); }

/* Dias da semana */
.days-table { border: 1px solid var(--border-color); border-radius: 10px; overflow: hidden; }
.days-header { display: grid; grid-template-columns: 120px 80px 1fr 1fr; padding: 10px 16px; background: var(--bg-tertiary); font-size: 0.75rem; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; gap: 12px; }
.day-row { display: grid; grid-template-columns: 120px 80px 1fr 1fr; align-items: center; padding: 10px 16px; border-top: 1px solid var(--border-color); gap: 12px; transition: background 0.15s; }
.day-row:hover { background: var(--bg-hover); }
.day-row.inactive { opacity: 0.5; }
.day-row.inactive:hover { background: transparent; }
.day-name { font-size: 0.9rem; font-weight: 600; color: var(--text-main); }

/* Datas bloqueadas */
.blocked-add { display: flex; gap: 10px; align-items: center; margin-bottom: 14px; }
.date-input { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 8px; padding: 8px 12px; color: var(--text-main); font-size: 0.9rem; }
.date-input:focus { outline: none; border-color: var(--primary); }
.btn-add-date { display: flex; align-items: center; gap: 6px; background: var(--primary); color: white; border: none; border-radius: 8px; padding: 8px 14px; font-size: 0.88rem; font-weight: 600; cursor: pointer; white-space: nowrap; }
.btn-add-date:hover { opacity: 0.9; }
.blocked-list { display: flex; flex-wrap: wrap; gap: 8px; }
.no-dates { font-size: 0.85rem; color: var(--text-muted); }
.blocked-chip { display: flex; align-items: center; gap: 6px; background: #fee2e2; border: 1px solid #fca5a5; color: #991b1b; border-radius: 20px; padding: 4px 10px; font-size: 0.85rem; font-weight: 500; }
.chip-remove { background: none; border: none; cursor: pointer; color: #991b1b; display: flex; align-items: center; padding: 0; }

/* Ações */
.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; }
.btn-primary { display: flex; align-items: center; gap: 6px; background: var(--primary); color: #fff; border: none; border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer; }
.btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-secondary { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; cursor: pointer; color: var(--text-main); }
.icon-sm { width: 16px; height: 16px; }

/* Convênios */
.plans-label { font-size: 0.78rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 12px; }
.plans-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px; }
.plan-check { display: flex; align-items: center; gap: 8px; padding: 8px 12px; border: 1px solid var(--border-color); border-radius: 8px; cursor: pointer; transition: background 0.15s, border-color 0.15s; font-size: 0.88rem; color: var(--text-main); }
.plan-check:hover { background: var(--bg-hover); }
.plan-check input[type="checkbox"] { width: 15px; height: 15px; accent-color: var(--primary); cursor: pointer; flex-shrink: 0; }
.plan-check input[type="checkbox"]:checked + .plan-name { color: var(--primary); font-weight: 600; }
.plan-check:has(input:checked) { border-color: var(--primary); background: rgba(13,148,136,0.06); }

@media (max-width: 768px) {
  .form-page { padding: 1rem; }
  .form-grid { grid-template-columns: 1fr; }
  .days-header, .day-row { grid-template-columns: 100px 60px 1fr 1fr; gap: 8px; padding: 8px 12px; font-size: 0.78rem; }
  .form-actions { flex-direction: column; button { width: 100%; } }
  .plans-grid { grid-template-columns: 1fr 1fr; }
}
</style>
