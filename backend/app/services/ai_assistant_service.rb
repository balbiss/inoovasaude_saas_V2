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

    Rails.cache.write("ai_paused_#{@inbox.id}_#{jid}", Time.current.to_i)

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

    <<~PROMPT
      #{base_prompt}
      Seu nome é #{@inbox.ai_name.presence || 'Ana'}. Seja sempre humana, empática e natural — nunca robótica.

      [DATA E HORA]: #{date_info}
      [PACIENTE]: #{patient_info}#{extra}

      ═══ FLUXO — NOVO PACIENTE (sem nome cadastrado) ═══
      1. Cumprimente gentilmente e se apresente.
      2. Pergunte o nome completo.
      3. Pergunte o CPF.
      4. Pergunte: tem convênio ou será particular?
         • Se convênio: qual o plano? (Número da carteirinha é OPCIONAL — NÃO insista.)
      5. Chame save_contact_data com os dados coletados.
      6. Avance para o fluxo de agendamento.

      ═══ FLUXO — AGENDAMENTO ═══
      1. Chame list_professionals_and_services para ver opções disponíveis.
      2. Apresente APENAS nome e especialidade do profissional. NUNCA mencione duração, preço ou valores — são dados internos.
      3. Pergunte qual profissional/serviço o paciente prefere.
         • Se o paciente tiver convênio, verifique se o profissional aceita o plano.
         • Se não aceitar, informe e ofereça alternativas ou consulta particular.
      4. Pergunte a data desejada.
      5. CONVERSÃO DE DATA — OBRIGATÓRIO antes de chamar check_availability:
         Hoje é #{Time.current.in_time_zone('America/Sao_Paulo').strftime('%A, %d/%m/%Y')}.
         Converta SEMPRE expressões relativas para YYYY-MM-DD:
         • "amanhã" → #{(Date.current + 1).strftime('%Y-%m-%d')}
         • "segunda" / "segunda-feira" → calcule a próxima segunda no formato YYYY-MM-DD
         • "terça", "quarta", etc → calcule o próximo dia correspondente
         • "essa semana" → pergunte qual dia específico
         Só chame check_availability após calcular a data exata em YYYY-MM-DD.
      6. SEMPRE chame check_availability(professional_id, date) com YYYY-MM-DD. NUNCA invente horários.
      7. Se não houver horários, informe e pergunte se quer tentar outro dia.
      8. Apresente os horários disponíveis de forma organizada e visual, respeitando os grupos manhã/tarde retornados pela ferramenta.
         Exemplo: "Temos os seguintes horários disponíveis:\n\n🌅 Manhã: 08:00 | 09:00 | 10:00\n☀️ Tarde: 14:00 | 15:00\n\nQual você prefere? 😊"
      9. Quando o paciente escolher um horário da lista já apresentada:
         • NÃO chame check_availability novamente — o horário já foi confirmado como disponível.
         • Vá direto para a confirmação: "Posso confirmar: [nome] com [profissional] no dia [data] às [hora]?"
      10. Após confirmação explícita do paciente ("sim", "pode ser", "confirma", etc.), chame book_appointment.

      ═══ REGRA DE RETORNO ═══
      • Retorno só é permitido se o paciente tiver comparecido a uma consulta anterior.
      • O retorno deve ser agendado dentro do prazo definido pela clínica (padrão: 30 dias).
      • book_appointment retornará um erro claro se o retorno não for permitido.
      • Nesse caso, oriente o paciente a agendar uma consulta regular.

      ═══ CONSULTA / CANCELAMENTO ═══
      • "Quando é minha consulta?" → peça o CPF → chame find_patient_appointments.
      • "Quero cancelar" → confirme os dados da consulta → chame cancel_appointment.
        Após cancelar, sempre ofereça remarcar.

      ═══ ENCERRAMENTO ═══
      • Após agendar com sucesso: aplique a etiqueta "consulta_agendada" com apply_label.
        Isso pausará a IA automaticamente.
      • Se o paciente pedir para falar com uma pessoa: aplique "com_atendente" e transfira.

      REGRAS ABSOLUTAS:
      ✗ NUNCA mencione duração de consulta, preço ou valores ao paciente.
      ✗ NUNCA invente horários. Use sempre check_availability com data em YYYY-MM-DD.
      ✗ NUNCA agende sem confirmação explícita do paciente.
      ✗ NUNCA pergunte número de carteirinha de forma obrigatória.
    PROMPT
  end

  # ── Definição das ferramentas ─────────────────────────────────────────────

  def defined_tools
    [
      {
        type: "function",
        function: {
          name: "save_contact_data",
          description: "Salva ou atualiza os dados cadastrais do paciente (nome, CPF, convênio). Chame assim que coletar as informações.",
          parameters: {
            type: "object",
            properties: {
              name:               { type: "string", description: "Nome completo do paciente" },
              cpf:                { type: "string", description: "CPF (apenas dígitos ou formatado)" },
              health_plan:        { type: "string", description: "Nome do convênio (ex: 'Unimed') ou 'particular'" },
              health_plan_number: { type: "string", description: "Número da carteirinha (opcional)" }
            },
            required: ["name"]
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
              label:  { type: "string", enum: ["consulta_agendada", "com_atendente", "paciente_quente", "paciente_frio", "sem_agenda"] },
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
      attrs[:name]               = args['name'].strip            if args['name'].present?
      attrs[:cpf]                = args['cpf'].gsub(/\D/, '')    if args['cpf'].present?
      attrs[:health_plan]        = args['health_plan']           if args['health_plan'].present?
      attrs[:health_plan_number] = args['health_plan_number']    if args['health_plan_number'].present?
      # Separa first_name / last_name a partir do nome completo
      if attrs[:name].present?
        parts = attrs[:name].split(' ', 2)
        attrs[:first_name] = parts[0]
        attrs[:last_name]  = parts[1] || ''
      end
      contact.update!(attrs)
      "Dados do paciente salvos: #{attrs.map { |k, v| "#{k}=#{v}" }.join(', ')}."

    when "list_professionals_and_services"
      professionals = account.professionals.where(status: 'active').order(:name)
      services      = account.services.where(status: 'active').order(:name)

      prof_list = professionals.map do |p|
        plans = Array(p.accepted_plans || [])
        particular = p.accepts_particular != false
        plan_str = [
          particular ? 'Particular' : nil,
          plans.presence&.join(', ')
        ].compact.join(' | ')
        "• ID #{p.id}: #{p.name} (#{p.specialty}) — Aceita: #{plan_str.presence || 'Consultar clínica'}"
      end

      svc_list = services.map do |s|
        "• ID #{s.id}: #{s.name}"
      end

      [
        "Profissionais disponíveis:", prof_list.presence&.join("\n") || "Nenhum profissional ativo.",
        "\nServiços disponíveis:", svc_list.presence&.join("\n") || "Nenhum serviço ativo."
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
        lines << "🌅 Manhã: #{morning.join(' | ')}"   if morning.any?
        lines << "☀️ Tarde: #{afternoon.join(' | ')}" if afternoon.any?
        lines.join("\n")
      end

    when "book_appointment"
      professional = account.professionals.find_by(id: args['professional_id'])
      return "❌ Profissional não encontrado." unless professional

      status_val        = args['status'].presence&.to_s.downcase
      status_val        = 'agendado' unless %w[agendado retorno].include?(status_val)
      consultation_type = args['consultation_type'].presence || 'presencial'
      date_str          = args['date'].to_s
      start_time        = args['start_time'].to_s

      # Validação de duplo agendamento
      if account.block_double_booking != false
        pending = account.appointments
          .where(contact_id: contact.id, status: %w[agendado confirmado])
          .exists?
        if pending
          return "❌ Este paciente já possui uma consulta pendente (agendada ou confirmada). Informe-o que é necessário cancelar ou aguardar a conclusão da consulta atual antes de agendar uma nova."
        end
      end

      # Validação de retorno
      if status_val == 'retorno'
        retorno_days = (account.retorno_days || 30).to_i
        last_done    = account.appointments
          .where(contact_id: contact.id, status: 'compareceu')
          .order(appointment_date: :desc)
          .first

        if last_done.nil?
          return "❌ Retorno não permitido: o paciente não possui consulta anterior registrada como realizada (compareceu). O retorno só pode ser agendado após uma consulta concluída."
        end

        days_since = (Date.current - last_done.appointment_date.to_date).to_i
        if days_since > retorno_days
          deadline = (last_done.appointment_date.to_date + retorno_days.days).strftime('%d/%m/%Y')
          return "❌ Prazo de retorno expirado. A última consulta foi em #{last_done.appointment_date.strftime('%d/%m/%Y')} e o prazo de #{retorno_days} dias encerrou em #{deadline}. Oriente o paciente a agendar uma consulta regular."
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
        contact_id:        contact.id,
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

      contact.update!(funnel_stage: 'agendado')

      "✅ Consulta agendada! ID #{appt.id} — #{professional.name} em #{Date.parse(date_str).strftime('%d/%m/%Y')} às #{start_time}. A confirmação será enviada por WhatsApp em seguida."

    when "find_patient_appointments"
      cpf_clean = args['cpf'].to_s.gsub(/\D/, '')
      found_contact = account.contacts.find_by(cpf: cpf_clean)
      return "Nenhum paciente encontrado com esse CPF." unless found_contact

      appts = account.appointments
        .where(contact_id: found_contact.id)
        .where('appointment_date >= ?', Date.current)
        .includes(:professional, :service)
        .order(appointment_date: :asc)
        .limit(5)

      return "#{found_contact.name} não possui consultas agendadas." if appts.empty?

      list = appts.map do |a|
        prof = a.professional&.name || '—'
        svc  = a.service&.name      || '—'
        "• ID #{a.id}: #{a.appointment_date.strftime('%d/%m/%Y')} às #{a.start_time} com #{prof} — #{svc} (#{a.status})"
      end
      "Consultas de #{found_contact.name}:\n#{list.join("\n")}"

    when "cancel_appointment"
      appt = account.appointments.find_by(id: args['appointment_id'])
      return "Consulta não encontrada." unless appt
      return "Esta consulta já está cancelada." if appt.status == 'cancelado'

      old_status = appt.status
      appt.update_columns(status: 'cancelado', updated_at: Time.current)
      AppointmentStatusNotificationJob.perform_later(appt.id, old_status, 'cancelado')

      "✅ Consulta ID #{appt.id} cancelada. O paciente receberá uma notificação pelo WhatsApp."

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

      if %w[consulta_agendada com_atendente].include?(label_name)
        pause_ai_permanently
        RoundRobinAssignmentService.assign_next(@conversation.reload) if label_name == 'com_atendente'
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
    Rails.logger.error("[AiAssistantService#execute_tool] #{name}: #{e.message}")
    "Erro ao executar ação. Tente novamente."
  end
end
