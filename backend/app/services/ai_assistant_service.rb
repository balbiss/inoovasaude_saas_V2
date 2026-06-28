require 'openai'

class AiAssistantService
  def initialize(inbox, conversation, extra_context: nil)
    @inbox = inbox
    @conversation = conversation
    @extra_context = extra_context
    api_key = GlobalSetting.fetch('openai_api_key').presence || ENV['OPENAI_API_KEY']
    @client = OpenAI::Client.new(access_token: api_key)
  end

  def self.transcribe_audio(media_data, filename, inbox)
    api_key = GlobalSetting.fetch('openai_api_key').presence || ENV['OPENAI_API_KEY']
    client = OpenAI::Client.new(access_token: api_key)

    tempfile = Tempfile.new([filename.split('.').first, ".#{filename.split('.').last}"])
    tempfile.binmode
    tempfile.write(media_data)
    tempfile.rewind

    response = client.audio.transcribe(
      parameters: { model: "whisper-1", file: File.open(tempfile.path, "rb") }
    )
    tempfile.close
    tempfile.unlink
    response["text"]
  end

  def process_message
    messages = build_message_history

    response = @client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [{ role: "system", content: build_system_prompt }] + messages,
        temperature: @inbox.ai_temperature || 0.7,
        tools: defined_tools,
        tool_choice: "auto"
      }
    )

    text = handle_response(response, messages)
    text.present? ? split_into_messages(text) : []
  end

  private

  # ── Infraestrutura (não muda) ─────────────────────────────────────────────

  def split_into_messages(text)
    return [text] if text.length < 80

    prompt = <<~P
      Você é um agente que simula o comportamento humano ao enviar mensagens no WhatsApp.
      Seu objetivo é pegar uma mensagem longa recebida como entrada e dividi-la em múltiplas mensagens menores — sem alterar as palavras — apenas separando em partes naturais.
      REGRAS:
      - Não reescreva o conteúdo. Apenas separe respeitando pontuação e pausas naturais.
      - Sempre retorne como JSON com campo "mensagens" (array de strings).
      - Remova vírgulas e pontos finais no fim das mensagens quando soar mais natural.
      - Mantenha cada mensagem entre 1 a 4 frases. NUNCA quebre em mais de 5 partes.
      - Mantenha itens de lista na mesma mensagem.
    P

    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        response_format: { type: "json_object" },
        messages: [{ role: "system", content: prompt }, { role: "user", content: text }],
        temperature: 0.3
      }
    )
    json_str = response.dig("choices", 0, "message", "content")
    JSON.parse(json_str)["mensagens"] || [text]
  rescue => e
    Rails.logger.error("split_into_messages: #{e.message}")
    [text]
  end

  def build_message_history
    @conversation.messages.order(created_at: :asc).last(100).map do |msg|
      role = msg.sender_type == 'Contact' ? 'user' : 'assistant'
      { role: role, content: msg.text || "📎 [Mídia/Anexo]" }
    end
  end

  def handle_response(response, messages)
    max_rounds = 5
    current_response = response

    max_rounds.times do
      choice = current_response.dig("choices", 0, "message")
      return choice["content"] unless choice["tool_calls"]

      all_results = choice["tool_calls"].map do |tc|
        fn   = tc.dig("function", "name")
        args = JSON.parse(tc.dig("function", "arguments"))
        { tool_call: tc, name: fn, result: execute_tool(fn, args).to_s }
      end

      messages << { role: "assistant", content: nil, tool_calls: choice["tool_calls"] }
      all_results.each do |r|
        messages << { role: "tool", tool_call_id: r[:tool_call]["id"], name: r[:name], content: r[:result] }
      end

      current_response = @client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [{ role: "system", content: build_system_prompt }] + messages,
          tools: defined_tools,
          tool_choice: "auto",
          temperature: @inbox.ai_temperature || 0.7
        }
      )
    end

    current_response.dig("choices", 0, "message", "content")
  end

  def pause_ai_permanently
    jid = @conversation.contact.jid.presence || @conversation.contact.phone
    return unless jid

    Rails.cache.write("ai_paused_#{@inbox.id}_#{jid}", Time.current.to_i, expires_in: 30.minutes)

    tag = @conversation.account.tags.find_or_create_by!(name: 'agente_off') { |t| t.color = '#f97316' }
    @conversation.tags << tag unless @conversation.tags.include?(tag)

    ActionCable.server.broadcast('conversations_channel', {
      event: 'conversation_tags_updated',
      conversation_id: @conversation.id,
      tags: @conversation.reload.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
    })
  rescue => e
    Rails.logger.error("pause_ai_permanently: #{e.message}")
  end

  # ── Prompt do sistema ─────────────────────────────────────────────────────

  def build_system_prompt
    base_prompt = @inbox.ai_prompt.presence || "Você é uma recepcionista virtual prestativa e empática."

    tz   = 'America/Sao_Paulo'
    now  = Time.current.in_time_zone(tz)
    dias = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado]
    date_info = "Hoje é #{dias[now.wday]}, #{now.strftime('%d/%m/%Y')}. Horário atual: #{now.strftime('%H:%M')}."

    contact    = @conversation.contact
    is_new     = contact.name.blank? || contact.name == contact.phone
    patient_info = if is_new
      "NOVO paciente (sem cadastro). Telefone: #{contact.phone}."
    else
      info  = "Paciente: #{contact.name}. Telefone: #{contact.phone}."
      info += " CPF: #{contact.cpf}." if contact.cpf.present?
      info += " Convênio: #{contact.health_plan}." if contact.health_plan.present?
      info += " Plano atual no funil: #{contact.funnel_stage}." if contact.funnel_stage.present?
      info
    end

    extra = @extra_context.present? ? "\n\n[CONTEXTO EXTRA]: #{@extra_context}" : ""

    booking_info = if @inbox.account.booking_enabled? && @inbox.account.booking_url.present?
      url = @inbox.account.booking_url
      "\n\n[AGENDAMENTO ONLINE ATIVADO]: #{url}\nSEMPRE QUE O PACIENTE QUISER AGENDAR: envie este link imediatamente sem chamar list_professionals_and_services. Diga: 'Pode agendar por este link: #{url} — la voce escolhe o profissional, data e horario!' NAO tente listar profissionais para fins de agendamento."
    else
      ""
    end

    <<~PROMPT
      #{base_prompt}
      Seu nome é #{@inbox.ai_name.presence || 'Ana'}. Seja sempre humana, empática e natural — nunca robótica.

      [DATA E HORA]: #{date_info}
      [PACIENTE]: #{patient_info}#{booking_info}#{extra}

      REGRA FUNDAMENTAL: faca UMA pergunta por mensagem. Nunca acumule perguntas. Nunca use formatacao markdown como **negrito** — o WhatsApp nao renderiza.

      ═══ FLUXO COMPLETO DE AGENDAMENTO ═══

      ETAPA 1 — MOSTRAR OPCOES (antes de pedir qualquer dado do paciente):
      1. Chame list_professionals_and_services imediatamente.
      2. Apresente cada profissional em um bloco compacto (tudo numa so mensagem por profissional):
           "[Nome] — [Especialidade]
            Agenda: Seg 08:00-17:00 | Qua 08:00-17:00 | Sex 08:00-12:00
            Convenios: Unimed, Particular
            Consulta: R$ 150,00" (inclua o valor do servico se disponivel)
      3. Pergunte: "Com qual profissional voce gostaria de agendar?"
         EXCECAO: se o paciente ja mencionou o nome do medico ou especialidade, pule direto para a ETAPA 2.
         • Se houver mais de um profissional na mesma especialidade, apresente os dois e pergunte qual prefere.
         • Se o paciente disser "qualquer um" ou similar, sugira o primeiro disponivel.

      ETAPA 2 — SELECIONAR DATA E HORARIO:
      4. Pergunte a data desejada. Use a agenda do profissional para orientar:
         se o paciente pedir um dia que o profissional nao atende, informe os dias corretos.
      5. CONVERSAO DE DATA — obrigatorio antes de check_availability:
         Hoje e #{Time.current.in_time_zone('America/Sao_Paulo').strftime('%A, %d/%m/%Y')}.
         • "amanha" → #{(Date.current + 1).strftime('%Y-%m-%d')}
         • "segunda" / "segunda-feira" → proxima segunda em YYYY-MM-DD
         • "terca", "quarta", etc → proximo dia correspondente
         • "essa semana" → pergunte qual dia especifico
      6. Chame check_availability(professional_id, date). NUNCA invente horarios.
         Sem horarios: informe e pergunte outra data. NAO desista.
      7. Apresente horarios separando manha e tarde:
         "Manha: 08:00 | 09:00 | 10:00
          Tarde: 14:00 | 15:00
          Qual horario voce prefere?"
      8. Paciente escolheu horario da lista: NAO rechame check_availability.

      ETAPA 3 — COLETAR DADOS DO PACIENTE (somente apos escolher profissional + data + horario):
      9.  Diga: "Para finalizar o agendamento, preciso de alguns dados." Pergunte APENAS o nome completo.
      10. Apos receber o nome, pergunte APENAS o CPF.
          • Se o paciente enviar nome e CPF juntos, aceite os dois e pule para o passo 11.
      11. Apos ter nome e CPF, pergunte APENAS: a consulta sera por convenio ou particular?
          • EXCECAO IMPORTANTE: se o profissional escolhido aceita APENAS um convenio (e nao aceita particular), nao pergunte qual plano — use esse unico convenio automaticamente e pule para o passo 12.
          • EXCECAO IMPORTANTE: se o profissional aceita APENAS particular, nao pergunte — use 'particular' automaticamente e pule para o passo 12.
          • Se aceitar mais de uma opcao: pergunte convenio ou particular. Se convenio: qual o plano? (carteirinha e OPCIONAL — nao insista)
      12. Com nome + CPF + convenio em maos, chame save_contact_data UMA VEZ com tudo junto.
          NAO chame save_contact_data parcialmente (so com nome, por exemplo).

      ETAPA 4 — CONFIRMAR E AGENDAR:
      13. Confirme tudo: "Posso confirmar: [nome] com [profissional] dia [data] as [hora]?"
      14. Apos confirmacao ("sim", "pode ser", "confirma", "isso"), chame book_appointment.

      CPF como identificador unico:
      O CPF e o identificador principal. O sistema detecta o mesmo paciente mesmo com numero diferente ou nome abreviado.
      Duplo agendamento e prazo de retorno sao verificados automaticamente por CPF ao chamar book_appointment.

      ═══ REGRA DE RETORNO ═══
      • Retorno so e permitido se o paciente tiver comparecido a uma consulta anterior.
      • book_appointment retorna erro claro se nao for permitido — oriente a agendar consulta regular.

      ═══ CONSULTA / CANCELAMENTO ═══
      • "Quando e minha consulta?" → peca o CPF → chame find_patient_appointments.
      • "Quero cancelar" → confirme os dados → chame cancel_appointment → oferea remarcar.

      ═══ ENCERRAMENTO ═══
      • Apos agendar: confirme cordialmente e pergunte se precisa de mais alguma coisa. IA continua ativa.
      • Se pedir para falar com pessoa/secretaria: aplique "com_atendente" e transfira.

      REGRAS ABSOLUTAS:
      ✗ NUNCA faca mais de uma pergunta por mensagem.
      ✗ NUNCA use markdown como **negrito** — escreva texto simples.
      ✗ NUNCA mencione duracao da consulta no meio da conversa.
      ✗ NUNCA invente horarios — use sempre check_availability.
      ✗ NUNCA agende sem confirmacao explicita do paciente.
      ✗ NUNCA pergunte numero de carteirinha de forma obrigatoria.
      ✗ NUNCA peca dados do paciente antes de o paciente escolher profissional, data e horario.
      ✗ NUNCA transfira para humano por causa de erro de agendamento — informe o paciente sobre o motivo (ex: ja possui consulta agendada) e oferea alternativas (outro dia, cancelar a anterior, etc).
      ✗ NUNCA pergunte qual o plano de saude quando o profissional aceita apenas uma opcao.
    PROMPT
  end

  # ── Definição das ferramentas ─────────────────────────────────────────────

  def defined_tools
    [
      {
        type: "function",
        function: {
          name: "save_contact_data",
          description: "Salva os dados cadastrais do paciente. SOMENTE chame esta funcao UMA VEZ, apos coletar nome + CPF + convenio juntos. Nunca chame so com o nome — espere ter todos os dados antes.",
          parameters: {
            type: "object",
            properties: {
              name:               { type: "string", description: "Nome completo do paciente" },
              cpf:                { type: "string", description: "CPF do paciente (digitos ou formatado). OBRIGATORIO para novos pacientes." },
              health_plan:        { type: "string", description: "Nome do convenio (ex: 'Unimed', 'Bradesco Saude') ou 'particular'" },
              health_plan_number: { type: "string", description: "Numero da carteirinha do convenio (opcional)" }
            },
            required: ["name", "cpf", "health_plan"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "list_professionals_and_services",
          description: "Lista os profissionais disponíveis na clínica (com especialidade e planos aceitos) e os serviços cadastrados.",
          parameters: { type: "object", properties: {} }
        }
      },
      {
        type: "function",
        function: {
          name: "check_availability",
          description: "Verifica os horários disponíveis de um profissional em uma data específica. SEMPRE chame antes de oferecer horários.",
          parameters: {
            type: "object",
            properties: {
              professional_id: { type: "integer", description: "ID do profissional" },
              date:            { type: "string",  description: "Data no formato YYYY-MM-DD" }
            },
            required: ["professional_id", "date"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "book_appointment",
          description: "Agenda uma consulta após o paciente confirmar todos os dados. Valida conflitos e regra de retorno automaticamente.",
          parameters: {
            type: "object",
            properties: {
              professional_id:   { type: "integer", description: "ID do profissional" },
              service_id:        { type: "integer", description: "ID do serviço (opcional)" },
              date:              { type: "string",  description: "Data no formato YYYY-MM-DD" },
              start_time:        { type: "string",  description: "Horário de início no formato HH:MM" },
              status:            { type: "string",  enum: ["agendado", "retorno"], description: "Use 'retorno' quando for retorno. Padrão: 'agendado'." },
              consultation_type: { type: "string",  enum: ["presencial", "online"], description: "Padrão: presencial" }
            },
            required: ["professional_id", "date", "start_time"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "find_patient_appointments",
          description: "Busca as próximas consultas de um paciente pelo CPF. Use quando o paciente perguntar quando é sua consulta.",
          parameters: {
            type: "object",
            properties: {
              cpf: { type: "string", description: "CPF do paciente" }
            },
            required: ["cpf"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "cancel_appointment",
          description: "Cancela uma consulta existente e envia notificação WhatsApp ao paciente.",
          parameters: {
            type: "object",
            properties: {
              appointment_id: { type: "integer", description: "ID da consulta a cancelar" }
            },
            required: ["appointment_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "apply_label",
          description: "Aplica uma etiqueta na conversa. Use 'consulta_agendada' após agendar (pausa a IA). Use 'com_atendente' quando precisar transferir para humano.",
          parameters: {
            type: "object",
            properties: {
              label:  { type: "string", enum: ["com_atendente", "paciente_quente", "paciente_frio", "sem_agenda"] },
              reason: { type: "string", description: "Motivo breve" }
            },
            required: ["label"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "transfer_to_human",
          description: "Transfere a conversa para uma secretária/atendente humana quando necessário.",
          parameters: {
            type: "object",
            properties: {
              reason: { type: "string", description: "Motivo da transferência" }
            },
            required: ["reason"]
          }
        }
      }
    ]
  end

  # ── Execução das ferramentas ──────────────────────────────────────────────

  def execute_tool(name, args)
    account = @conversation.account
    contact = @conversation.contact

    case name

    when "save_contact_data"
      attrs = {}
      attrs[:name]               = args['name'].strip              if args['name'].present?
      attrs[:cpf]                = args['cpf'].to_s.gsub(/\D/, '') if args['cpf'].present?
      attrs[:health_plan]        = args['health_plan']             if args['health_plan'].present?
      attrs[:health_plan_number] = args['health_plan_number']      if args['health_plan_number'].present?
      if attrs[:name].present?
        parts = attrs[:name].split(' ', 2)
        attrs[:first_name] = parts[0]
        attrs[:last_name]  = parts[1] || ''
      end
      contact.update!(attrs)
      Rails.logger.info("[AiAssistant] save_contact_data contact##{contact.id}: #{attrs.keys.join(', ')}")

      # Verifica se CPF ja existe em outro contato (mesmo paciente, numero diferente)
      result = "Dados salvos: #{attrs.slice(:name, :cpf, :health_plan).map { |k, v| "#{k}=#{v}" }.join(', ')}."
      if attrs[:cpf].present?
        canonical = account.contacts.where(cpf: attrs[:cpf]).where.not(id: contact.id).order(:created_at).first
        if canonical
          result += " ATENCAO: este CPF ja esta cadastrado no paciente '#{canonical.name}' (ID #{canonical.id}, fone #{canonical.phone}). O historico de agendamentos deste CPF sera verificado nas validacoes de duplo agendamento e retorno."
          Rails.logger.info("[AiAssistant] CPF duplicado: contact##{contact.id} -> canonical##{canonical.id}")
        end
      end
      result

    when "list_professionals_and_services"
      professionals = account.professionals.where(status: 'active').order(:name)
      services      = account.services.where(status: 'active').order(:name)

      if professionals.empty?
        booking_url = account.booking_url if account.booking_enabled?
        return booking_url.present? \
          ? "NENHUM PROFISSIONAL CADASTRADO. Use o link de agendamento: #{booking_url} — envie ao paciente para ele agendar sozinho." \
          : "Nenhum profissional cadastrado na clinica no momento. Informe o paciente e peca para tentar mais tarde."
      end

      day_order  = %w[segunda terca quarta quinta sexta sabado domingo]
      day_labels = {
        'segunda' => 'Seg', 'terca' => 'Ter', 'quarta' => 'Qua',
        'quinta'  => 'Qui', 'sexta' => 'Sex', 'sabado' => 'Sab', 'domingo' => 'Dom'
      }

      prof_list = professionals.map do |p|
        plans      = Array(p.accepted_plans || [])
        particular = p.accepts_particular != false
        options    = [particular ? 'Particular' : nil, plans.presence&.join(', ')].compact
        plan_str   = options.join(', ')

        # Indica explicitamente quando ha apenas UMA opcao para a IA nao perguntar
        plan_display = if options.size == 1
          "#{plan_str} (unica opcao — nao perguntar ao paciente)"
        else
          plan_str.presence || 'Consultar clinica'
        end

        schedule = (p.schedule || {}).with_indifferent_access
        schedule_parts = day_order.filter_map do |key|
          day = schedule[key]
          next unless day.present? && day['active'].to_s == 'true'
          "#{day_labels[key]} #{day['start']}-#{day['end']}"
        end
        schedule_str = schedule_parts.any? ? schedule_parts.join(' | ') : 'Consultar clinica'

        # Formato em bloco unico separado por \n (nao \n\n) para nao fragmentar
        [
          "[ID #{p.id}] #{p.name} — #{p.specialty}",
          "Agenda: #{schedule_str}",
          "Convenios: #{plan_display}"
        ].join("\n")
      end

      # Servicos com preco (para referencia da IA ao apresentar ao paciente)
      svc_list = services.map do |s|
        price_str = s.price.present? ? " — R$ #{format('%.2f', s.price.to_f).gsub('.', ',')}" : ''
        "[ID #{s.id}] #{s.name}#{price_str}"
      end

      # Blocos separados por linha em branco para que o split_into_messages mantenha cada profissional junto
      [
        "PROFISSIONAIS:",
        prof_list.join("\n\n"),
        "\nSERVICOS:",
        svc_list.join("\n")
      ].join("\n")

    when "check_availability"
      professional = account.professionals.find_by(id: args['professional_id'])
      return "Profissional não encontrado." unless professional

      date = begin
        Date.parse(args['date'].to_s)
      rescue
        return "ERRO: data '#{args['date']}' inválida. Converta para o formato YYYY-MM-DD antes de chamar check_availability (ex: 2026-06-23)."
      end
      slots = AgentAvailabilityService.new(professional).available_slots(date)

      if slots.empty?
        "Nenhum horário disponível para #{professional.name} em #{date.strftime('%d/%m/%Y')}. O profissional pode não atender nesse dia ou todos os horários já estão ocupados."
      else
        morning   = slots.select { |s| s < "12:00" }
        afternoon = slots.reject { |s| s < "12:00" }
        lines = ["Horários disponíveis para #{professional.name} em #{date.strftime('%d/%m/%Y')}:"]
        lines << "Manha: #{morning.join(' | ')}"   if morning.any?
        lines << "Tarde: #{afternoon.join(' | ')}" if afternoon.any?
        lines.join("\n")
      end

    when "book_appointment"
      professional = account.professionals.find_by(id: args['professional_id'])
      return "Profissional nao encontrado." unless professional

      status_val        = args['status'].presence&.to_s.downcase
      status_val        = 'agendado' unless %w[agendado retorno].include?(status_val)
      consultation_type = args['consultation_type'].presence || 'presencial'
      date_str          = args['date'].to_s
      start_time        = args['start_time'].to_s

      # Resolve contato canonico pelo CPF — detecta mesmo paciente com numeros diferentes
      cpf_clean = contact.cpf.to_s.gsub(/\D/, '').presence
      if cpf_clean.present?
        contact_ids = account.contacts.where(cpf: cpf_clean).pluck(:id)
        # Contato canonico = o mais antigo com este CPF (tem o historico completo)
        canonical_contact = account.contacts.where(cpf: cpf_clean).order(:created_at).first || contact
      else
        contact_ids = [contact.id]
        canonical_contact = contact
      end
      Rails.logger.info("[AiAssistant] book_appointment CPF=#{cpf_clean.inspect} contact_ids=#{contact_ids.inspect} canonical=#{canonical_contact.id}")

      # Validacao de duplo agendamento (verifica TODOS os contatos com mesmo CPF)
      if account.block_double_booking != false
        pending = account.appointments
          .where(contact_id: contact_ids, status: %w[agendado confirmado])
          .exists?
        if pending
          return "Este paciente ja possui uma consulta pendente (agendada ou confirmada). Nao e possivel agendar nova consulta enquanto houver uma em aberto — mesmo que use outro numero de telefone."
        end
      end

      # Validacao de retorno (verifica historico completo do CPF)
      if status_val == 'retorno'
        retorno_days = (account.retorno_days || 30).to_i
        last_done    = account.appointments
          .where(contact_id: contact_ids, status: 'compareceu')
          .order(appointment_date: :desc)
          .first

        if last_done.nil?
          return "Retorno nao permitido: nenhuma consulta anterior registrada como realizada para este CPF. O retorno so pode ser agendado apos uma consulta concluida."
        end

        days_since = (Date.current - last_done.appointment_date.to_date).to_i
        if days_since > retorno_days
          deadline = (last_done.appointment_date.to_date + retorno_days.days).strftime('%d/%m/%Y')
          return "Prazo de retorno expirado. A ultima consulta foi em #{last_done.appointment_date.strftime('%d/%m/%Y')} e o prazo de #{retorno_days} dias encerrou em #{deadline}. Oriente o paciente a agendar uma consulta regular."
        end
      end

      # Calcula fim da consulta
      duration = professional.consultation_duration || 30
      end_time = begin
        (Time.parse(start_time) + duration.minutes).strftime('%H:%M')
      rescue
        nil
      end

      appt = Appointment.create!(
        account_id:        account.id,
        contact_id:        canonical_contact.id,
        professional_id:   professional.id,
        service_id:        args['service_id'],
        user_id:           @conversation.user_id,
        appointment_date:  date_str,
        start_time:        start_time,
        end_time:          end_time,
        status:            status_val,
        consultation_type: consultation_type,
        notes:             "Agendado via assistente virtual"
      )

      # Atualiza funil no contato canonico
      canonical_contact.update!(funnel_stage: 'agendado')

      "Consulta agendada com sucesso. ID #{appt.id} — #{professional.name} em #{Date.parse(date_str).strftime('%d/%m/%Y')} as #{start_time}."

    when "find_patient_appointments"
      cpf_clean = args['cpf'].to_s.gsub(/\D/, '')
      # Busca todos os contatos com este CPF para retornar historico completo
      contacts_with_cpf = account.contacts.where(cpf: cpf_clean)
      return "Nenhum paciente encontrado com esse CPF." if contacts_with_cpf.empty?

      found_contact = contacts_with_cpf.order(:created_at).first

      all_ids = contacts_with_cpf.pluck(:id)

      appts = account.appointments
        .where(contact_id: all_ids)
        .where('appointment_date >= ?', Date.current)
        .includes(:professional, :service)
        .order(appointment_date: :asc)
        .limit(5)

      return "#{found_contact.name} nao possui consultas agendadas." if appts.empty?

      list = appts.map do |a|
        prof = a.professional&.name || '—'
        svc  = a.service&.name      || '—'
        "• ID #{a.id}: #{a.appointment_date.strftime('%d/%m/%Y')} as #{a.start_time} com #{prof} — #{svc} (#{a.status})"
      end
      "Consultas de #{found_contact.name}:\n#{list.join("\n")}"

    when "cancel_appointment"
      appt = account.appointments.find_by(id: args['appointment_id'])
      return "Consulta não encontrada." unless appt
      return "Esta consulta já está cancelada." if appt.status == 'cancelado'

      old_status = appt.status
      appt.update_columns(status: 'cancelado', updated_at: Time.current)
      AppointmentStatusNotificationJob.perform_later(appt.id, old_status, 'cancelado')

      "Consulta ID #{appt.id} cancelada com sucesso. O paciente sera notificado pelo WhatsApp."

    when "apply_label"
      label_name = args['label'].to_s.strip.downcase
      colors = {
        'consulta_agendada' => '#10b981',
        'com_atendente'     => '#8b5cf6',
        'paciente_quente'   => '#ef4444',
        'paciente_frio'     => '#3b82f6',
        'sem_agenda'        => '#94a3b8'
      }
      color = colors[label_name] || '#6b7280'

      tag = @conversation.account.tags.find_or_create_by!(name: label_name) { |t| t.color = color }
      @conversation.tags << tag unless @conversation.tags.include?(tag)

      ActionCable.server.broadcast('conversations_channel', {
        event: 'conversation_tags_updated',
        conversation_id: @conversation.id,
        tags: @conversation.reload.tags.map { |t| { id: t.id, name: t.name, color: t.color } }
      })

      if label_name == 'com_atendente'
        pause_ai_permanently
        RoundRobinAssignmentService.assign_next(@conversation.reload)
      end

      "Etiqueta '#{label_name}' aplicada."

    when "transfer_to_human"
      agent = account.users.where(status: 'active', role: [:secretaria, :admin]).order(:id).first

      if agent
        @conversation.update!(user_id: agent.id)
        ActionCable.server.broadcast('conversations_channel', {
          event: 'lead_atribuido',
          assigned_to_user_id: agent.id,
          conversation_id:     @conversation.id,
          contact_name:        contact.name.presence || contact.phone,
          assigned_by:         'ia_routing'
        })
        AgentNotificationService.notify_assignment(agent: agent, conversation: @conversation, assigned_by: 'ia') rescue nil
        pause_ai_permanently
        "Conversa transferida para #{agent.first_name}. IA pausada."
      else
        "Nenhuma secretária disponível no momento. Informando ao paciente."
      end

    else
      "Ferramenta não reconhecida: #{name}"
    end
  rescue => e
    Rails.logger.error("[AiAssistantService#execute_tool] #{name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    "Erro interno ao executar '#{name}': #{e.message}. Informe o paciente do problema especifico sem transferir para humano."
  end
end
