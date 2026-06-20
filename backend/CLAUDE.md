# InoovaSaúde — Backend (Rails 8)

## Visão Geral
CRM SaaS para clínicas de saúde (médica, estética, psicologia, fisioterapia, nutrição, etc.).
Produto do usuário Guilherme Balbis (inoovawebpro@gmail.com).
Repositório: `https://github.com/balbiss/inoovasaude_saas_V2`
Pasta local: `C:\Users\inoov\inoovasaude_saas_V2\backend`
Deploy via: Docker Swarm + Portainer

## Stack Backend
- Ruby on Rails 8 (API mode)
- PostgreSQL
- Devise + Devise-JWT (autenticação)
- ActionCable (WebSocket para chat em tempo real)
- Sidekiq + Redis (background jobs)
- OpenAI GPT-4o-mini (resumo de conversa, IA de atendimento)
- Asaas (cobrança/billing)
- VAPID (push notifications)
- Baileys WhatsApp API

## Modelos Principais
- `User` — roles: atendente(0), empresa(1), admin(2). Campo `status` ('active'/'blocked'). `permissions` JSON.
- `Account` — tenant/clínica cliente do SaaS
- `Contact` — paciente. Campos: name, phone, email, temperature, source, funnel_stage, blood_type, allergies, health_notes, health_plan, health_plan_number, medical_history, cpf, birth_date, profession
- `Professional` — médico/especialista. Campos: name, specialty, council_number, phone, email, bio, status
- `Service` — tipo de serviço/consulta. Campos: name, description, duration_minutes, price, category, status
- `Appointment` — consulta agendada. Campos: contact_id, professional_id, service_id, appointment_date, start_time, end_time, status, consultation_type, notes, confirmation_sent_at, reminder_sent_at
- `MedicalRecord` — prontuário. Campos: patient_id, professional_id, appointment_id, recorded_by_id, chief_complaint, diagnosis, prescription, notes
- `Conversation` — conversa de WhatsApp. status: open/resolved/snoozed
- `Message` — mensagem. `is_private: true` para notas internas
- `Inbox` — canal WhatsApp (Baileys)
- `Tag` — etiquetas para conversas
- `Notification` — notificações in-app
- `PushSubscription` — para notificações push VAPID

## Funil Clínico (funnel_stage em Contact)
`novo_paciente` → `agendado` → `compareceu` → `retorno`

## Status de Appointment
`agendado` → `confirmado` → `compareceu` / `nao_compareceu` / `cancelado` / `retorno`

## Jobs
- `AppointmentConfirmationJob` — envia WhatsApp de confirmação via Baileys ao criar consulta, agenda o reminder
- `AppointmentReminderJob` — envia WhatsApp de lembrete 1 dia antes da consulta
- `AiFollowupJob` — follow-up automático de pacientes inativos via WhatsApp
- `CheckSnoozedConversationsJob` — verifica conversas em snooze
- `SendScheduledMessageJob` — envia mensagens agendadas

## Controllers Importantes
- `Admin::BaseController` — base para `/admin/*`, exige `role == admin`
- `Users::SessionsController` — login JWT
- `ProfessionalsController` — CRUD de profissionais
- `ServicesController` — CRUD de serviços
- `MedicalRecordsController` — CRUD de prontuários (filtra por patient_id, professional_id)
- `AppointmentsController` — ações: report (by_professional), export CSV
- `ConversationsController` — transferência com nota privada
- `BillingController` — integração Asaas

## Rotas Relevantes
```
resources :professionals
resources :services
resources :medical_records
resources :appointments → GET /appointments/report, GET /appointments/export
namespace :admin → dashboard, accounts, support_tickets, settings
namespace :webhooks → baileys, stripe
```

## Autenticação
- Devise-JWT com JTI matcher
- `active_for_authentication?` verifica `status == 'active'`
- Super admin: `User` com `role: :admin` e `account` vinculado

## Deploy
1. Alterações em `inoovasaude_saas_V2/backend/`
2. `git add` + `git commit` + `git push`
3. Portainer: atualizar serviço backend
4. Rodar `bundle exec rails db:migrate` no container após deploy

## Comandos Úteis (via Portainer Exec no container backend)
```bash
bundle exec rails console
bundle exec rails db:migrate
bundle exec rails db:seed
```

## Integração com Frontend
- Pasta local frontend: `C:\Users\inoov\inoovasaude_saas_V2\frontend`
- O frontend consome esta API REST via Axios
- WebSocket via ActionCable (`/cable`) para chat em tempo real
- Para qualquer mudança que envolva nova rota, novo campo ou nova lógica de negócio, é necessário alterar **os dois projetos**

## Serviços Importantes
- `WhatsappBaileysService` — envio de mensagens, presença, foto de perfil, QR code
- `AiAssistantService` — IA de atendimento (OpenAI GPT-4o-mini)
- `AsaasService` — integração de pagamentos

## Diferenças vs CRM Imobiliário (VisitaIA)
| Imobiliário | Clínica |
|---|---|
| Property | Professional |
| Condominium | Service |
| contact.intention | contact.funnel_stage |
| Visita Agendada | Consulta Agendada |
| PropertyMatchJob | AppointmentConfirmationJob + ReminderJob |
| canal_pro/zap/viva_real webhooks | Removidos |
