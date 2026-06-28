<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import {
  MessageCircle, Users, CalendarDays, Kanban,
  TrendingUp, Badge, Settings, CreditCard, BrainCircuit, Bell,
  BookOpen, ChevronRight, Search, Bot, Shield, ArrowRightLeft,
  Stethoscope, FlaskConical, UserRound
} from 'lucide-vue-next'

const activeSection = ref('visao-geral')
const searchQuery   = ref('')

const sections = [
  { id: 'visao-geral',    label: 'Visão Geral',              icon: BookOpen },
  { id: 'conversas',      label: 'Conversas',                icon: MessageCircle },
  { id: 'transferencia',  label: 'Transferência de Conversa',icon: ArrowRightLeft },
  { id: 'pacientes',      label: 'Pacientes',                icon: UserRound },
  { id: 'profissionais',  label: 'Profissionais',            icon: Stethoscope },
  { id: 'servicos',       label: 'Serviços',                 icon: FlaskConical },
  { id: 'agendamentos',   label: 'Agendamentos',             icon: CalendarDays },
  { id: 'funil',          label: 'Funil Clínico',            icon: Kanban },
  { id: 'relatorios',     label: 'Relatórios',               icon: TrendingUp },
  { id: 'agentes',        label: 'Equipe',                   icon: Badge },
  { id: 'configuracoes',  label: 'Configurações',            icon: Settings },
  { id: 'cobranca',       label: 'Cobrança (Asaas)',         icon: CreditCard },
  { id: 'ia',             label: 'Inteligência Artificial',  icon: BrainCircuit },
  { id: 'notificacoes',   label: 'Notificações Push',        icon: Bell },
  { id: 'permissoes',     label: 'Permissões',               icon: Shield },
]

const filteredSections = ref(sections)

const filterSections = () => {
  const q = searchQuery.value.toLowerCase()
  filteredSections.value = q
    ? sections.filter(s => s.label.toLowerCase().includes(q))
    : sections
}

const scrollTo = (id) => {
  activeSection.value = id
  const el = document.getElementById(id)
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

const handleScroll = () => {
  for (const s of [...sections].reverse()) {
    const el = document.getElementById(s.id)
    if (el && el.getBoundingClientRect().top <= 120) {
      activeSection.value = s.id
      break
    }
  }
}

onMounted(() => document.querySelector('.manual-content')?.addEventListener('scroll', handleScroll))
onUnmounted(() => document.querySelector('.manual-content')?.removeEventListener('scroll', handleScroll))
</script>

<template>
  <div class="manual-page">

    <!-- Sidebar nav -->
    <aside class="manual-nav">
      <div class="nav-header">
        <BookOpen :size="16" />
        <span>Manual do Sistema</span>
      </div>

      <div class="nav-search">
        <Search :size="13" />
        <input v-model="searchQuery" @input="filterSections" placeholder="Buscar seção..." />
      </div>

      <nav>
        <button
          v-for="s in filteredSections"
          :key="s.id"
          class="nav-link"
          :class="{ active: activeSection === s.id }"
          @click="scrollTo(s.id)"
        >
          <component :is="s.icon" :size="14" />
          {{ s.label }}
          <ChevronRight :size="12" class="arrow" />
        </button>
      </nav>
    </aside>

    <!-- Content -->
    <div class="manual-content">
      <div class="content-inner">

        <!-- ══════════════════════════════════════ VISÃO GERAL -->
        <section id="visao-geral">
          <h1>Visão Geral do Sistema</h1>
          <p class="lead">O <strong>InoovaSaúde CRM</strong> é uma plataforma completa de gestão para clínicas de saúde. Centraliza conversas do WhatsApp, pacientes, agendamentos, prontuários e cobranças em um único lugar.</p>

          <div class="cards-row">
            <div class="info-card">
              <MessageCircle :size="20" />
              <div>
                <strong>Atendimento unificado</strong>
                <p>Todas as conversas do WhatsApp em um painel único, com histórico completo e atendimento por múltiplos profissionais.</p>
              </div>
            </div>
            <div class="info-card">
              <Bot :size="20" />
              <div>
                <strong>IA integrada</strong>
                <p>Assistente de IA responde automaticamente, resume conversas e gera prompts personalizados por canal.</p>
              </div>
            </div>
            <div class="info-card">
              <CalendarDays :size="20" />
              <div>
                <strong>Agendamento automático</strong>
                <p>Confirmação e lembrete de consulta enviados automaticamente via WhatsApp ao paciente.</p>
              </div>
            </div>
          </div>

          <h2>Estrutura do sistema</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Módulo</th><th>Quem acessa</th><th>Função principal</th></tr></thead>
              <tbody>
                <tr><td>Dashboard</td><td>Todos</td><td>KPIs, pacientes do dia, funil clínico</td></tr>
                <tr><td>Conversas</td><td>Todos</td><td>Chat WhatsApp em tempo real</td></tr>
                <tr><td>Pacientes</td><td>Todos*</td><td>Base de pacientes com histórico</td></tr>
                <tr><td>Profissionais</td><td>Secretaria/Admin</td><td>Cadastro de médicos e especialistas</td></tr>
                <tr><td>Serviços</td><td>Secretaria/Admin</td><td>Tipos de consulta e procedimentos</td></tr>
                <tr><td>Agendamentos</td><td>Todos</td><td>Consultas e compromissos</td></tr>
                <tr><td>Funil Clínico</td><td>Todos</td><td>Pipeline visual de pacientes</td></tr>
                <tr><td>Relatórios</td><td>Todos</td><td>Performance e métricas</td></tr>
                <tr><td>Equipe</td><td>Secretaria/Admin</td><td>Gerenciar usuários do sistema</td></tr>
                <tr><td>Configurações</td><td>Secretaria/Admin</td><td>Canais, tags, integrações</td></tr>
                <tr><td>Cobrança</td><td>Financeiro+</td><td>PIX e boleto pelo WhatsApp</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">* Médicos veem apenas seus próprios pacientes. Secretaria e admins veem tudo.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONVERSAS -->
        <section id="conversas">
          <h1>Conversas</h1>
          <p class="lead">O painel de conversas é o centro operacional do CRM. Todas as mensagens recebidas pelo WhatsApp aparecem aqui em tempo real.</p>

          <h2>Layout do painel</h2>
          <p>O painel é dividido em três colunas:</p>
          <ol>
            <li><strong>Lista de conversas</strong> (esquerda) — todas as conversas com filtros e busca</li>
            <li><strong>Chat</strong> (centro) — histórico completo de mensagens</li>
            <li><strong>Detalhes do paciente</strong> (direita) — informações do paciente em tempo real</li>
          </ol>

          <h2>Status das conversas</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Status</th><th>Significado</th></tr></thead>
              <tbody>
                <tr><td><span class="badge green">Aberta</span></td><td>Conversa ativa, aguardando ou em atendimento</td></tr>
                <tr><td><span class="badge yellow">Pendente</span></td><td>Aguardando resposta do paciente</td></tr>
                <tr><td><span class="badge gray">Resolvida</span></td><td>Atendimento encerrado</td></tr>
                <tr><td><span class="badge blue">Adiada</span></td><td>Pausada com data para retomar automaticamente</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Envio de mensagens</h2>
          <ul>
            <li><strong>Texto:</strong> Digite e pressione Enter ou clique em enviar</li>
            <li><strong>Anexos:</strong> Clique no ícone de clipe para enviar arquivos, imagens ou áudio</li>
            <li><strong>Emojis:</strong> Clique no ícone de emoji para abrir o seletor</li>
            <li><strong>Mensagem privada:</strong> Ative o modo "nota interna" para mensagens visíveis apenas para a equipe</li>
            <li><strong>Agendar mensagem:</strong> Clique no ícone de relógio para enviar em horário específico</li>
          </ul>

          <h2>Atribuição de conversas</h2>
          <ul>
            <li>Novas conversas são distribuídas via <strong>rodízio automático</strong> entre os médicos disponíveis</li>
            <li>A secretaria pode reatribuir manualmente no painel lateral direito</li>
            <li>O profissional recebe notificação push e mensagem no WhatsApp pessoal</li>
          </ul>

          <h2>Resumo por IA</h2>
          <p>Clique em <strong>"Resumo IA"</strong> no menu da conversa para gerar automaticamente um resumo do histórico. Útil para quando um profissional assume um atendimento de outro.</p>

          <h2>Filtros disponíveis</h2>
          <ul>
            <li>Por status (aberta, pendente, resolvida, adiada)</li>
            <li>Por profissional atribuído</li>
            <li>Por canal (inbox/WhatsApp)</li>
            <li>Por tag/etiqueta</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ TRANSFERÊNCIA -->
        <section id="transferencia">
          <h1>Transferência de Conversa entre Profissionais</h1>
          <p class="lead">Transfira uma conversa para outro profissional com uma nota de contexto — a nota aparece como mensagem privada no chat, visível apenas para a equipe.</p>

          <h2>Como transferir</h2>
          <ol>
            <li>Abra a conversa que deseja transferir</li>
            <li>No painel direito, em <strong>Atendente</strong>, veja o profissional atual</li>
            <li>Clique em <strong>"Transferir com nota"</strong></li>
            <li>Selecione o <strong>profissional de destino</strong></li>
            <li>Escreva a <strong>nota de contexto</strong> — queixa do paciente, histórico relevante, motivo da transferência</li>
            <li>Clique em <strong>Transferir</strong></li>
          </ol>

          <h2>O que acontece após a transferência</h2>
          <ul>
            <li>A conversa é atribuída ao novo profissional</li>
            <li>O novo profissional recebe uma <strong>notificação push</strong></li>
            <li>A nota de transferência aparece no chat como <strong>mensagem privada</strong> (fundo amarelado), visível apenas para a equipe</li>
          </ul>

          <div class="info-card" style="margin-top: 1rem;">
            <ArrowRightLeft :size="20" />
            <div>
              <strong>Dica de uso</strong>
              <p>Use a transferência quando o médico responsável não está disponível, quando o paciente precisa de outra especialidade, ou quando há troca de plantão.</p>
            </div>
          </div>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ PACIENTES -->
        <section id="pacientes">
          <h1>Pacientes</h1>
          <p class="lead">Todos os pacientes captados pelo WhatsApp ou cadastrados manualmente ficam armazenados aqui com seu histórico completo.</p>

          <h2>Campos do paciente</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Campo</th><th>Descrição</th></tr></thead>
              <tbody>
                <tr><td>Nome</td><td>Nome completo do paciente</td></tr>
                <tr><td>Telefone / WhatsApp</td><td>Número principal de contato</td></tr>
                <tr><td>E-mail</td><td>E-mail para envios e confirmações</td></tr>
                <tr><td>CPF</td><td>Necessário para gerar cobranças via Asaas</td></tr>
                <tr><td>Data de Nascimento</td><td>Para cálculo de idade e personalização</td></tr>
                <tr><td>Plano de Saúde</td><td>Operadora e número da carteirinha</td></tr>
                <tr><td>Tipo Sanguíneo</td><td>Informação clínica relevante</td></tr>
                <tr><td>Alergias</td><td>Registro de alergias a medicamentos/substâncias</td></tr>
                <tr><td>Observações de Saúde</td><td>Histórico médico e condições crônicas</td></tr>
                <tr><td>Origem</td><td>WhatsApp, Google, Indicação, Site etc.</td></tr>
                <tr><td>Estágio do Funil</td><td>Novo Paciente / Agendado / Compareceu / Retorno</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Estágio no funil clínico</h2>
          <ul>
            <li><span class="badge blue">Novo Paciente</span> — primeiro contato, ainda não agendou</li>
            <li><span class="badge yellow">Agendado</span> — consulta marcada</li>
            <li><span class="badge green">Compareceu</span> — paciente foi atendido</li>
            <li><span class="badge green">Retorno</span> — paciente voltou para nova consulta</li>
          </ul>

          <h2>Notas</h2>
          <p>Na aba <strong>Notas</strong> do paciente, qualquer profissional pode registrar observações que ficam visíveis para toda a equipe, com data, hora e autoria.</p>

          <h2>Mesclar pacientes</h2>
          <p>Quando o mesmo paciente aparece duplicado, use <strong>Pacientes → Mesclar</strong>. O sistema mantém o histórico completo do registro principal.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ PROFISSIONAIS -->
        <section id="profissionais">
          <h1>Profissionais de Saúde</h1>
          <p class="lead">Cadastre os médicos e especialistas da clínica com suas especialidades, horários de atendimento e tempo de consulta.</p>

          <h2>Cadastrando um profissional</h2>
          <ol>
            <li>Acesse <strong>Profissionais → Novo Profissional</strong></li>
            <li>Preencha nome, especialidade e número do conselho (CRM, CRO etc.)</li>
            <li>Configure a disponibilidade: quais dias da semana atende e os horários</li>
            <li>Defina o <strong>tempo de consulta</strong> em minutos (usado para gerar slots automáticos)</li>
            <li>Clique em <strong>Salvar</strong></li>
          </ol>

          <h2>Campos disponíveis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Campo</th><th>Descrição</th></tr></thead>
              <tbody>
                <tr><td>Nome</td><td>Nome completo do profissional</td></tr>
                <tr><td>Especialidade</td><td>Ex: Cardiologia, Dermatologia, Fisioterapia</td></tr>
                <tr><td>Número do Conselho</td><td>CRM, CRO, CREFITO etc.</td></tr>
                <tr><td>Telefone / E-mail</td><td>Contato direto do profissional</td></tr>
                <tr><td>Bio</td><td>Descrição e experiência profissional</td></tr>
                <tr><td>Status</td><td>Ativo / Inativo</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Quem pode gerenciar</h2>
          <p>Apenas usuários com papel <strong>Secretaria</strong> ou <strong>Admin</strong> podem criar, editar e inativar profissionais.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ SERVIÇOS -->
        <section id="servicos">
          <h1>Serviços / Procedimentos</h1>
          <p class="lead">Cadastre os tipos de consulta e procedimentos oferecidos pela clínica, com duração e valor.</p>

          <h2>Cadastrando um serviço</h2>
          <ol>
            <li>Acesse <strong>Serviços → Novo Serviço</strong></li>
            <li>Informe o nome (ex: "Consulta Cardiologia", "Limpeza de Pele")</li>
            <li>Defina a <strong>duração em minutos</strong></li>
            <li>Informe o <strong>valor</strong> (para cobranças via Asaas)</li>
            <li>Selecione a categoria e clique em <strong>Salvar</strong></li>
          </ol>

          <h2>Vinculação com agendamentos</h2>
          <p>Ao criar um agendamento, você vincula o paciente a um serviço específico. A duração do serviço preenche automaticamente o horário de fim da consulta.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ AGENDAMENTOS -->
        <section id="agendamentos">
          <h1>Agendamentos</h1>
          <p class="lead">Agende consultas e procedimentos vinculando paciente, profissional, serviço, data e horário — com confirmação automática via WhatsApp.</p>

          <h2>Criando um agendamento</h2>
          <ol>
            <li>Acesse <strong>Agendamentos → Novo Agendamento</strong></li>
            <li>Selecione o <strong>paciente</strong></li>
            <li>Selecione o <strong>profissional</strong> responsável</li>
            <li>Selecione o <strong>serviço/procedimento</strong></li>
            <li>Defina a <strong>data e horário</strong></li>
            <li>Clique em <strong>Salvar</strong> — a confirmação é enviada automaticamente pelo WhatsApp</li>
          </ol>

          <h2>Confirmação e lembrete automáticos</h2>
          <ul>
            <li><strong>Confirmação:</strong> enviada automaticamente ao salvar o agendamento</li>
            <li><strong>Lembrete:</strong> enviado automaticamente 1 dia antes da consulta</li>
          </ul>

          <h2>Status dos agendamentos</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Status</th><th>Significado</th></tr></thead>
              <tbody>
                <tr><td><span class="badge blue">Agendado</span></td><td>Consulta marcada, aguardando realização</td></tr>
                <tr><td><span class="badge green">Confirmado</span></td><td>Paciente confirmou presença</td></tr>
                <tr><td><span class="badge green">Compareceu</span></td><td>Consulta realizada</td></tr>
                <tr><td><span class="badge red">Não Compareceu</span></td><td>Paciente faltou</td></tr>
                <tr><td><span class="badge red">Cancelado</span></td><td>Consulta cancelada</td></tr>
                <tr><td><span class="badge yellow">Retorno</span></td><td>Consulta de retorno agendada</td></tr>
              </tbody>
            </table>
          </div>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ FUNIL -->
        <section id="funil">
          <h1>Funil Clínico (Kanban)</h1>
          <p class="lead">Visualize e gerencie o fluxo de pacientes em formato Kanban, movendo pacientes entre etapas com arrastar e soltar.</p>

          <h2>Etapas do funil</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Coluna</th><th>Significado</th></tr></thead>
              <tbody>
                <tr><td>Novo Paciente</td><td>Paciente entrou em contato, ainda não agendou</td></tr>
                <tr><td>Agendado</td><td>Consulta marcada, aguardando a data</td></tr>
                <tr><td>Compareceu</td><td>Paciente foi atendido na clínica</td></tr>
                <tr><td>Retorno</td><td>Paciente com retorno marcado ou recorrente</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Como usar</h2>
          <ul>
            <li><strong>Mover paciente:</strong> Arraste o card de uma coluna para outra</li>
            <li><strong>Adicionar paciente:</strong> Clique em "+" em qualquer coluna para cadastrar manualmente</li>
            <li><strong>Ver detalhes:</strong> Clique no card para abrir o perfil completo do paciente</li>
          </ul>

          <h2>Informações nos cards</h2>
          <p>Cada card mostra: nome do paciente, estágio atual, plano de saúde e observações de saúde relevantes.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ RELATÓRIOS -->
        <section id="relatorios">
          <h1>Relatórios</h1>
          <p class="lead">Acompanhe a performance da equipe e da clínica com relatórios detalhados e exportáveis.</p>

          <h2>Abas disponíveis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Aba</th><th>O que mostra</th></tr></thead>
              <tbody>
                <tr><td>Visão Geral</td><td>Total de pacientes, funil clínico, origem, taxa de retorno</td></tr>
                <tr><td>Por Profissional</td><td>Performance individual: pacientes, consultas, taxa de confirmação</td></tr>
                <tr><td>Por Tag</td><td>Contagem de pacientes por etiqueta</td></tr>
                <tr><td>Performance</td><td>Tendência dos últimos 7 dias, tempo médio de resposta</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Filtro de período</h2>
          <p>Todos os relatórios aceitam filtro por: <strong>Hoje, Esta semana, Este mês, Período personalizado</strong>.</p>

          <h2>Exportar CSV</h2>
          <p>Clique em <strong>Exportar</strong> em qualquer relatório para baixar os dados em formato CSV compatível com Excel ou Google Sheets.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ AGENTES -->
        <section id="agentes">
          <h1>Equipe / Usuários do Sistema</h1>
          <p class="lead">Gerencie os usuários que utilizam o CRM — médicos, secretárias, suporte e financeiro.</p>

          <h2>Papéis disponíveis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Papel</th><th>Função</th><th>Recebe pacientes via rodízio</th></tr></thead>
              <tbody>
                <tr><td>Médico</td><td>Atende pacientes e realiza consultas</td><td>Sim</td></tr>
                <tr><td>Secretária</td><td>Gestão da clínica e agendamentos</td><td>Não</td></tr>
                <tr><td>Suporte</td><td>Atendimento e suporte aos pacientes</td><td>Não</td></tr>
                <tr><td>Financeiro</td><td>Cobranças e contratos</td><td>Não</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Criando um usuário</h2>
          <ol>
            <li>Acesse <strong>Equipe → Novo Profissional</strong></li>
            <li>Preencha nome, e-mail, papel e senha temporária</li>
            <li>O usuário receberá um e-mail com os dados de acesso automaticamente</li>
          </ol>

          <h2>Rodízio automático (Round Robin)</h2>
          <p>O rodízio distribui novos pacientes automaticamente entre os médicos de forma equilibrada:</p>
          <ul>
            <li><strong>Ativar no rodízio:</strong> toggle verde na lista — o médico entra na fila</li>
            <li><strong>Desativar:</strong> toggle cinza — o médico não recebe pacientes automáticos</li>
          </ul>
          <p>A fila de posição está visível em <strong>Equipe → Fila de Rodízio</strong>.</p>

          <h2>Bloquear usuário</h2>
          <p>Usuários bloqueados não conseguem mais fazer login. Use quando um profissional deixa a clínica.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONFIGURAÇÕES -->
        <section id="configuracoes">
          <h1>Configurações</h1>
          <p class="lead">Área exclusiva da secretaria/administrador para configurar canais, integrações e personalizações do CRM.</p>

          <h2>Caixas de Entrada (Inboxes)</h2>
          <p>Cada inbox representa um número de WhatsApp conectado. Para conectar:</p>
          <ol>
            <li>Acesse <strong>Configurações → Caixas de Entrada → Nova Caixa</strong></li>
            <li>Escaneie o QR Code com o WhatsApp do número da clínica</li>
            <li>Configure o <strong>prompt de IA</strong> para esse canal (tom de voz, apresentação, regras)</li>
            <li>Defina <strong>horário de funcionamento</strong> e mensagem fora do horário</li>
          </ol>

          <h2>Etiquetas (Tags)</h2>
          <p>Crie e personalize as etiquetas usadas nas conversas em <strong>Configurações → Etiquetas</strong>. Cada tag tem nome e cor.</p>

          <h2>Conta</h2>
          <p>Em <strong>Configurações → Conta</strong>, altere o nome da clínica e a senha de acesso.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ COBRANÇA -->
        <section id="cobranca">
          <h1>Cobrança via Asaas (PIX e Boleto)</h1>
          <p class="lead">Gere cobranças diretamente pelo painel de conversas e envie automaticamente para o paciente pelo WhatsApp.</p>

          <h2>Configuração inicial (apenas secretaria/admin)</h2>
          <ol>
            <li>Acesse <strong>Configurações → Cobrança (Asaas)</strong></li>
            <li>Cole a sua <strong>API Key do Asaas</strong> (encontrada em: Asaas → Configurações → Integrações → API)</li>
            <li>Selecione o ambiente: <strong>Sandbox</strong> para testes ou <strong>Produção</strong> para uso real</li>
            <li>Clique em <strong>Salvar</strong> e depois <strong>Testar conexão</strong> para confirmar</li>
          </ol>

          <h2>Gerando uma cobrança</h2>
          <ol>
            <li>Abra uma conversa com o paciente</li>
            <li>Clique no botão verde <strong>Cobrança</strong> no painel de ações</li>
            <li>Se o paciente não tiver CPF cadastrado, o sistema solicitará antes de continuar</li>
            <li>Escolha o tipo: <strong>PIX</strong> ou <strong>Boleto</strong></li>
            <li>Informe: valor, data de vencimento e descrição</li>
            <li>Clique em <strong>Gerar</strong></li>
          </ol>

          <h2>Como é enviado</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Tipo</th><th>O que é enviado no WhatsApp</th></tr></thead>
              <tbody>
                <tr><td>PIX</td><td>Imagem do QR Code + código Copia e Cola como texto</td></tr>
                <tr><td>Boleto</td><td>Arquivo PDF do boleto como documento</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Quem pode gerar cobranças</h2>
          <p>Financeiro, Suporte, Secretaria e Admin. <strong>Médicos não têm acesso</strong> à função de cobrança por padrão.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ IA -->
        <section id="ia">
          <h1>Inteligência Artificial</h1>
          <p class="lead">O CRM usa IA (OpenAI GPT) para responder pacientes automaticamente, resumir conversas e gerar prompts personalizados.</p>

          <h2>Resposta automática</h2>
          <p>Quando a IA está ativa em um canal, ela responde automaticamente as mensagens recebidas fora do horário de atendimento ou enquanto nenhum profissional está disponível. O comportamento é definido pelo <strong>Prompt de IA</strong> configurado no canal.</p>

          <h2>Pausa da IA</h2>
          <p>Para pausar a IA em uma conversa específica, use a opção <strong>Pausar IA</strong> no menu da conversa. Para reativar, use <strong>Retomar IA</strong>.</p>

          <h2>Resumo automático de conversa</h2>
          <p>Em qualquer conversa, clique em <strong>Resumo IA</strong> para gerar automaticamente um resumo do histórico. Ideal para quando um profissional assume um atendimento de outro sem precisar ler tudo.</p>

          <h2>Gerador de Prompt</h2>
          <p>Em <strong>Configurações → Caixas de Entrada → editar inbox</strong>, use o botão <strong>Gerar Prompt com IA</strong>. O sistema cria automaticamente um prompt profissional baseado nas informações que você fornecer sobre a clínica.</p>

          <h2>Boas práticas para o Prompt</h2>
          <ul>
            <li>Defina o nome da assistente virtual (ex: "Ana, da Clínica Saúde Total")</li>
            <li>Liste o que a IA pode e não pode responder (ex: nunca dar diagnóstico)</li>
            <li>Inclua o horário de atendimento humano</li>
            <li>Defina o tom: acolhedor, empático, profissional</li>
            <li>Instrua a IA a sempre coletar nome, telefone e queixa principal do paciente</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ NOTIFICAÇÕES -->
        <section id="notificacoes">
          <h1>Notificações Push</h1>
          <p class="lead">Receba alertas no celular mesmo quando o CRM não está aberto — igual a um app nativo.</p>

          <h2>Como ativar</h2>
          <ol>
            <li>Acesse o CRM pelo celular no navegador (<strong>Chrome no Android</strong> ou <strong>Safari no iOS</strong>)</li>
            <li>Instale o app: no Android, o Chrome exibe o banner automaticamente. No iOS, toque em Compartilhar → Adicionar à Tela de Início</li>
            <li>Ao fazer login, o sistema solicita permissão para notificações</li>
            <li>Toque em <strong>Permitir</strong></li>
          </ol>

          <h2>O que gera notificações</h2>
          <ul>
            <li>Novo paciente atribuído ao profissional (via rodízio automático ou atribuição manual)</li>
          </ul>

          <h2>Compatibilidade</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Dispositivo</th><th>Suporte</th><th>Observação</th></tr></thead>
              <tbody>
                <tr><td>Android (Chrome)</td><td><span class="badge green">Completo</span></td><td>Funciona sem instalar</td></tr>
                <tr><td>iOS 16.4+</td><td><span class="badge yellow">Parcial</span></td><td>App deve estar instalado na tela inicial</td></tr>
                <tr><td>iOS abaixo de 16.4</td><td><span class="badge gray">Não suportado</span></td><td>Limitação da Apple</td></tr>
              </tbody>
            </table>
          </div>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ PERMISSÕES -->
        <section id="permissoes">
          <h1>Permissões por Papel</h1>
          <p class="lead">O CRM tem três papéis principais com níveis de acesso distintos, garantindo a privacidade dos dados de cada clínica.</p>

          <h2>Papéis do sistema</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Papel</th><th>Descrição</th></tr></thead>
              <tbody>
                <tr><td><strong>Secretaria / Admin da Clínica</strong></td><td>Acesso total ao CRM, configurações, equipe e relatórios completos</td></tr>
                <tr><td><strong>Médico</strong></td><td>Acesso às suas próprias consultas, pacientes e conversas</td></tr>
                <tr><td><strong>Super Admin</strong></td><td>Painel administrativo do SaaS — exclusivo da equipe técnica InoovaSaúde</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Tabela de permissões</h2>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Função</th>
                  <th>Médico</th>
                  <th>Secretaria</th>
                </tr>
              </thead>
              <tbody>
                <tr><td>Ver suas conversas</td><td>✅</td><td>✅</td></tr>
                <tr><td>Ver todas as conversas</td><td>❌</td><td>✅</td></tr>
                <tr><td>Receber pacientes (rodízio)</td><td>✅</td><td>❌</td></tr>
                <tr><td>Gerar cobrança PIX/Boleto</td><td>❌</td><td>✅</td></tr>
                <tr><td>Gerenciar equipe</td><td>❌</td><td>✅</td></tr>
                <tr><td>Acessar configurações</td><td>❌</td><td>✅</td></tr>
                <tr><td>Ver relatórios</td><td>✅*</td><td>✅</td></tr>
                <tr><td>Gerenciar profissionais</td><td>❌</td><td>✅</td></tr>
                <tr><td>Gerenciar serviços</td><td>❌</td><td>✅</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">* Médicos veem apenas dados dos seus próprios pacientes. Secretaria vê dados de toda a equipe.</p>

          <h2>Isolamento multi-clínica</h2>
          <p>Cada clínica tem seus próprios dados completamente isolados. Nenhum dado de uma clínica é visível para outra. O isolamento é garantido em todas as consultas ao banco de dados pelo campo <strong>account_id</strong>.</p>
        </section>

        <div class="divider" />

        <div class="footer-note">
          <p>Dúvidas ou problemas? Acesse <strong>Suporte</strong> no menu lateral para abrir um chamado com a equipe técnica InoovaSaúde.</p>
        </div>

      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.manual-page {
  display: flex;
  height: 100%;
  overflow: hidden;
  background: var(--bg-primary);
}

// ── Sidebar nav ─────────────────────────────────────────────
.manual-nav {
  width: 220px;
  flex-shrink: 0;
  border-right: 1px solid var(--border-color);
  background: var(--bg-secondary);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.nav-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1rem 0.75rem;
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  border-bottom: 1px solid var(--border-color);
}

.nav-search {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6rem 0.75rem;
  border-bottom: 1px solid var(--border-color);
  color: var(--text-muted);

  input {
    flex: 1;
    background: none;
    border: none;
    outline: none;
    font-size: 0.8rem;
    color: var(--text-main);
    &::placeholder { color: var(--text-muted); }
  }
}

nav {
  flex: 1;
  overflow-y: auto;
  padding: 0.4rem 0;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.55rem 1rem;
  font-size: 0.82rem;
  color: var(--text-muted);
  background: none;
  border: none;
  text-align: left;
  cursor: pointer;
  transition: background 0.12s, color 0.12s;

  .arrow { margin-left: auto; opacity: 0; transition: opacity 0.12s; }

  &:hover {
    background: var(--bg-hover);
    color: var(--text-main);
    .arrow { opacity: 0.5; }
  }
  &.active {
    background: rgba(13,148,136,0.08);
    color: var(--primary);
    font-weight: 600;
    .arrow { opacity: 1; }
  }
}

// ── Content ──────────────────────────────────────────────────
.manual-content {
  flex: 1;
  overflow-y: auto;
  padding: 2rem 2.5rem;
}

.content-inner {
  max-width: 820px;
}

section {
  scroll-margin-top: 1rem;
  margin-bottom: 0.5rem;

  h1 {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--text-main);
    margin: 0 0 0.5rem;
  }

  h2 {
    font-size: 1rem;
    font-weight: 600;
    color: var(--text-main);
    margin: 1.5rem 0 0.6rem;
    padding-bottom: 0.35rem;
    border-bottom: 1px solid var(--border-color);
  }

  p, li { font-size: 0.9rem; color: var(--text-muted); line-height: 1.7; }
  ul, ol { padding-left: 1.5rem; margin: 0.5rem 0; }
  li { margin-bottom: 0.3rem; }
}

.lead {
  font-size: 0.95rem !important;
  color: var(--text-main) !important;
  margin-bottom: 1.2rem;
  padding: 0.75rem 1rem;
  background: rgba(13,148,136,0.06);
  border-left: 3px solid var(--primary);
  border-radius: 0 6px 6px 0;
}

.cards-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.75rem;
  margin: 1rem 0;
}

.info-card {
  display: flex;
  gap: 0.75rem;
  padding: 1rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  font-size: 0.85rem;

  svg { flex-shrink: 0; color: var(--primary); margin-top: 2px; }
  strong { display: block; color: var(--text-main); font-size: 0.88rem; margin-bottom: 0.3rem; }
  p { margin: 0; font-size: 0.82rem; color: var(--text-muted); }
}

.table-wrap {
  overflow-x: auto;
  margin: 0.75rem 0;

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;

    th {
      text-align: left;
      padding: 0.6rem 0.75rem;
      background: var(--bg-secondary);
      color: var(--text-main);
      font-weight: 600;
      border-bottom: 2px solid var(--border-color);
    }

    td {
      padding: 0.55rem 0.75rem;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border-color);
    }

    tr:hover td { background: var(--bg-hover); }
  }
}

.badge {
  display: inline-flex;
  align-items: center;
  padding: 0.15rem 0.55rem;
  border-radius: 10px;
  font-size: 0.78rem;
  font-weight: 600;

  &.green  { background: rgba(16,185,129,0.12); color: #065f46; }
  &.yellow { background: rgba(245,158,11,0.12); color: #92400e; }
  &.red    { background: rgba(239,68,68,0.12);  color: #991b1b; }
  &.gray   { background: rgba(107,114,128,0.12);color: #374151; }
  &.blue   { background: rgba(59,130,246,0.12); color: #1e3a5f; }
}

.code-block {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.75rem 1rem;
  font-family: monospace;
  font-size: 0.85rem;
  color: var(--text-main);
  margin: 0.75rem 0;
  line-height: 1.5;
}

.note {
  font-size: 0.82rem !important;
  color: var(--text-muted) !important;
  font-style: italic;
  margin-top: 0.5rem;
}

.divider {
  border: none;
  border-top: 1px solid var(--border-color);
  margin: 2rem 0;
}

.footer-note {
  text-align: center;
  padding: 1.5rem;
  color: var(--text-muted);
  font-size: 0.88rem;
  background: var(--bg-secondary);
  border-radius: 8px;
  border: 1px solid var(--border-color);
  margin-top: 1rem;
}
</style>
