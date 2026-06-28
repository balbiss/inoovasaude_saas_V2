# InoovaSaúde — CRM SaaS para Clínicas

CRM SaaS completo para clínicas de saúde: médica, estética, psicologia, fisioterapia, nutrição e mais.

## Estrutura do Monorepo

```
inoovasaude_saas_V2/
  backend/    → Rails 8 API (PostgreSQL + Sidekiq + Baileys)
  frontend/   → Vue 3 + Pinia + Vite
```

## Funcionalidades

- **Ficha do Paciente** — dados pessoais, tipo sanguíneo, alergias, plano de saúde, histórico
- **Profissionais** — cadastro de médicos, psicólogos, fisioterapeutas, etc. com CRM/CRP/CRN
- **Serviços** — tipos de consulta com duração e preço
- **Agendamentos** — seleção de profissional, serviço, horário auto-preenchido por duração
- **WhatsApp Automático** — confirmação + lembrete 24h antes via Baileys
- **Funil Clínico** — Kanban: Novo Paciente → Agendado → Compareceu → Retorno
- **Prontuário** — registro de queixa, diagnóstico, prescrição por consulta
- **Relatórios** — por profissional/especialidade, por período, exportação CSV
- **Chat WhatsApp** — atendimento em tempo real com IA (GPT-4o-mini)
- **Cobrança** — integração Asaas (boleto, PIX, cartão)
- **Multi-tenant** — cada clínica tem sua conta isolada

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Backend | Ruby on Rails 8 API, PostgreSQL |
| Auth | Devise + Devise-JWT |
| Jobs | Sidekiq + Redis |
| WhatsApp | Baileys API |
| IA | OpenAI GPT-4o-mini |
| Frontend | Vue 3 + Pinia + Vite |
| UI | Lucide Icons + SCSS |
| Deploy | Docker Swarm + Portainer |
| Pagamentos | Asaas |

## Configuração

Ver `backend/CLAUDE.md` e `frontend/CLAUDE.md` para instruções detalhadas.
