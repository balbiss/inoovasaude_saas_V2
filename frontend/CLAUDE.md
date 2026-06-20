# InoovaSaúde — Frontend (Vue 3)

## Visão Geral
CRM SaaS para clínicas de saúde (médica, estética, psicologia, fisioterapia, nutrição, etc.).
Produto do usuário Guilherme Balbis (inoovawebpro@gmail.com).
Repositório: `https://github.com/balbiss/inoovasaude_saas_V2`
Pasta local: `C:\Users\inoov\inoovasaude_saas_V2\frontend`
Deploy via: Docker Swarm + Portainer
Cor primária: `#0d9488` (teal — identidade visual InoovaSaúde)

## Stack Frontend
- Vue 3 + `<script setup>` (Composition API)
- Pinia (store/estado global)
- Vue Router 4
- Lucide Vue Next (ícones)
- SweetAlert2 (toasts e alertas)
- Axios via `src/api.js`
- SCSS scoped em cada componente

## Estrutura de Pastas
```
src/
  views/           → páginas principais
  components/      → componentes reutilizáveis
  store/           → Pinia stores
  router/index.js  → rotas + guards
  api.js           → instância Axios
  config/brand.js  → nome/marca (InoovaSaúde)
  composables/     → usePushNotifications.js
```

## Rotas Principais
- `/login` → Login.vue
- `/dashboard` → DashboardLayout.vue (wrapper com sidebar)
  - `/pacientes` → Contacts.vue (lista de pacientes)
  - `/pacientes/:id` → ContactDetails.vue (ficha do paciente)
  - `/profissionais` → Professionals.vue (OWNER)
  - `/profissionais/novo` / `/:id/editar` → ProfessionalForm.vue
  - `/servicos` → ClinicServices.vue (OWNER)
  - `/servicos/novo` / `/:id/editar` → ClinicServiceForm.vue
  - `/agendamentos` → Appointments.vue
  - `/agendamentos/novo` / `/:id/editar` → AppointmentForm.vue
  - `/agentes` → Agents.vue (OWNER)
  - `/funil` → Kanban.vue (estágios: novo_paciente → agendado → compareceu → retorno)
  - `/relatorios` → Reports.vue
  - `/manual` → Manual.vue
  - `/conversas` → Conversas.vue (chat WhatsApp)
  - `/settings/inboxes` → SettingsInboxes.vue
  - `/settings/account` → Account.vue
  - `/settings/tags` → Tags.vue
  - `/settings/asaas` → Asaas.vue
- `/admin` → AdminLayout.vue (super admin SaaS)

## Autenticação
- JWT via Devise-JWT (backend)
- Token salvo em `localStorage('auth_token')`
- Usuário em `localStorage('user')` (JSON: id, email, first_name, last_name, role, account_id)
- Roles: `atendente`, `empresa`, `admin`
- Super admin: role `admin` → acessa `/admin`

## Stores Pinia
- `conversations.js` — chat em tempo real + ActionCable
- `contacts.js` — lista de pacientes
- `professionals.js` — lista de profissionais
- `clinic_services.js` — lista de serviços
- `appointments.js` — agendamentos + fetchMetaData (contacts, professionals, services, agents)
- `agents.js` — equipe/atendentes
- `inboxes.js` — canais WhatsApp
- `dashboard.js` — métricas

## Funcionalidades Implementadas
- Chat em tempo real (ActionCable WebSocket)
- WhatsApp via Baileys
- Confirmação automática de consulta via WhatsApp (backend AppointmentConfirmationJob)
- Lembrete automático 1 dia antes (AppointmentReminderJob)
- Funil Kanban clínico: novo_paciente → agendado → compareceu → retorno
- Agendamentos com seleção de profissional, serviço, horário auto-preenchido
- Relatórios por profissional
- Notificações push (VAPID)
- Cobrança via Asaas
- Exportação de pacientes CSV

## Padrões de Código
- Sempre usar `<script setup>` com `ref()`, `computed()`
- Ícones: importar de `lucide-vue-next` (Stethoscope, FlaskConical, etc.)
- Toasts: `Swal.fire({ toast: true, position: 'top-end', ... })`
- API calls: `import api from '../api'`
- SCSS scoped: usar variáveis CSS `var(--primary)` etc.

## Variáveis CSS Globais (tema)
```css
--primary: #0d9488  /* teal InoovaSaúde */
--primary-hover: #0f766e
--bg-primary, --bg-secondary, --bg-tertiary, --bg-hover
--text-main, --text-muted, --text-inverse
--border-color
--shadow-color, --shadow-sm
--input-focus
```

## Deploy
1. Alterações em `inoovasaude_saas_V2/frontend/`
2. `git add` + `git commit` + `git push`
3. Portainer: atualizar serviço frontend (pull + redeploy)
4. Backend em `inoovasaude_saas_V2/backend/` → mesmo fluxo, serviço separado

## Diferenças vs CRM Imobiliário (VisitaIA)
| Imobiliário | Clínica |
|---|---|
| `/contatos` | `/pacientes` |
| `/imoveis` (Properties) | `/profissionais` (Professionals) |
| `/condominios` (Condominiums) | `/servicos` (ClinicServices) |
| "Funil de Vendas" | "Funil Clínico" |
| cor primária `#4338ca` | cor primária `#0d9488` teal |
| store/properties.js | store/professionals.js |
| store/condominiums.js | store/clinic_services.js |
