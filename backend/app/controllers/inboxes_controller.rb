require_relative '../services/whatsapp_baileys_service'

class InboxesController < ApplicationController
  before_action :set_inbox, only: %i[ show update destroy qr_code status disconnect reconnect generate_prompt ]
  before_action :require_owner!, only: %i[ create update destroy qr_code disconnect reconnect generate_prompt ]

  def index
    @inboxes = current_user.account.inboxes
    render json: @inboxes
  end

  def show
    render json: @inbox
  end

  def create
    @inbox = current_user.account.inboxes.new(inbox_params)

    if @inbox.save
      if @inbox.provider == 'baileys'
        webhook_url = "#{ENV.fetch('API_HOST', 'http://localhost:3000')}/webhooks/baileys"
        service = WhatsappBaileysService.new(@inbox)
        # Attempt to create the connection in the external Baileys API
        service.create_connection(webhook_url) rescue StandardError
      end
      
      render json: @inbox, status: :created
    else
      render json: @inbox.errors, status: :unprocessable_entity
    end
  end

  def update
    if @inbox.update(inbox_params)
      render json: @inbox
    else
      render json: @inbox.errors, status: :unprocessable_entity
    end
  end

  def qr_code
    baileys = WhatsappBaileysService.new(@inbox)
    qr = baileys.fetch_qr_code
    
    if qr.nil?
      status = Rails.cache.read("inbox:#{@inbox.id}:status")
      unless %w[connecting open].include?(status)
        baileys.delete_connection rescue nil
        sleep 0.5
        webhook_url = "#{ENV.fetch('API_HOST', 'http://localhost:3000')}/webhooks/baileys"
        baileys.create_connection(webhook_url) rescue nil
        sleep 2.0
        qr = baileys.fetch_qr_code
      end
    end

    if qr
      render json: { qr_code: qr }
    else
      render json: { qr_code: nil, message: 'QR Code não disponível. Tente novamente em instantes.' }
    end
  end

  def status
    baileys = WhatsappBaileysService.new(@inbox)
    connected = baileys.connected?
    render json: { connected: connected }
  end

  def disconnect
    baileys = WhatsappBaileysService.new(@inbox)
    baileys.delete_connection
    Rails.cache.delete("inbox:#{@inbox.id}:status")
    Rails.cache.delete("inbox:#{@inbox.id}:qr_code")
    ActionCable.server.broadcast("conversations_channel", {
      event: 'inbox_updated',
      inbox_id: @inbox.id,
      connection_status: 'close',
      qr_code: nil
    })
    render json: { message: 'Desconectado com sucesso.' }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reconnect
    baileys = WhatsappBaileysService.new(@inbox)
    baileys.delete_connection rescue nil
    Rails.cache.delete("inbox:#{@inbox.id}:status")
    Rails.cache.delete("inbox:#{@inbox.id}:qr_code")
    sleep 0.5
    webhook_url = "#{ENV.fetch('API_HOST', 'http://web:3000')}/webhooks/baileys"
    baileys.create_connection(webhook_url)
    render json: { message: 'Reconexão iniciada. Aguarde o QR Code.' }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    conv_count = @inbox.conversations.count
    contact_count = @inbox.conversations.joins(:contact).select('contacts.id').distinct.count

    begin
      WhatsappBaileysService.new(@inbox).delete_connection
    rescue StandardError => e
      Rails.logger.error("Failed to delete connection in Baileys: #{e.message}")
    end

    # Preserva histórico: conversations ficam com inbox_id = null (dependent: :nullify)
    @inbox.destroy!

    head :no_content, headers: {
      'X-Preserved-Conversations' => conv_count.to_s,
      'X-Preserved-Contacts' => contact_count.to_s
    }
  end

  def generate_prompt
    data = params.require(:prompt_data).permit(:identity, :institutional, :faq, :greeting_message, :sdr_rules, :routing_rules, :ai_role, :allow_scheduling, :use_whatsapp_name, :emoji_usage, :prohibited_actions)
    
    system_prompt = <<~PROMPT
      Você é um Engenheiro de Prompts especialista em IA para Clínicas de Saúde.
      Sua tarefa é criar um System Prompt detalhado, preciso e à prova de falhas para a IA de atendimento de uma clínica, baseado nas informações fornecidas.
      O prompt gerado será usado como a diretriz de comportamento primária da IA no WhatsApp da clínica.
      Sempre retorne APENAS o texto do prompt final, sem introduções ou explicações.
    PROMPT

    role_instruction = data[:ai_role] == 'sdr_only' ? "ATUAÇÃO RESTRITA A TRIAGEM: A IA NÃO agenda consultas por conta própria. O objetivo é APENAS qualificar o paciente, coletar informações e encaminhar para a recepção." : "ATUAÇÃO COMPLETA: A IA atua como assistente de triagem e agendamento, podendo qualificar o paciente, informar sobre serviços, convênios e realizar ou facilitar o agendamento de consultas."
    schedule_instruction = if data[:allow_scheduling] == 'true' || data[:allow_scheduling] == true
      "AGENDAMENTO AUTOMÁTICO: A IA PODE e DEVE realizar o agendamento de consultas diretamente no sistema quando o paciente quiser marcar. Verifique disponibilidade antes de confirmar."
    else
      "SEM AGENDAMENTO DIRETO: A IA NÃO agenda consultas diretamente. Quando o paciente quiser agendar, envie o link de agendamento online que estará disponível no contexto da conversa (variável [LINK DE AGENDAMENTO ONLINE]). Se não houver link disponível, oriente o paciente a ligar ou aguardar contato da recepção."
    end
    name_instruction = data[:use_whatsapp_name] ? "NOME DO PACIENTE E TELEFONE: O sistema já fornecerá o nome do paciente. Inicie o atendimento chamando-o pelo nome. NUNCA pergunte qual é o nome. Como JÁ ESTÃO no WhatsApp, NUNCA PERGUNTE O TELEFONE DE CONTATO, você já tem essa informação implicitamente." : "NOME DO PACIENTE E TELEFONE: Pergunte o nome do paciente de forma educada no início. No entanto, como já estão conversando pelo WhatsApp, NUNCA PERGUNTE O TELEFONE DE CONTATO."
    
    emoji_instruction = case data[:emoji_usage]
                        when 'none' then "PROIBIDO USO DE EMOJIS: Não utilize emojis em nenhuma circunstância. Mantenha a comunicação estritamente em texto limpo."
                        when 'lots' then "USO FREQUENTE DE EMOJIS: Utilize bastantes emojis para tornar a conversa muito descontraída, calorosa e jovem."
                        else "USO MODERADO DE EMOJIS: Utilize emojis de forma equilibrada e profissional para dar um tom amigável, sem exagerar."
                        end
                        
    prohibitions_instruction = data[:prohibited_actions].present? ? "AÇÕES ESTRITAMENTE PROIBIDAS (NUNCA FAÇA ISSO): #{data[:prohibited_actions]}" : "AÇÕES PROIBIDAS: Nenhuma extra."
    greeting_instruction = data[:greeting_message].present? ? "MENSAGEM DE SAUDAÇÃO EXATA (Primeiro Contato): Use exatamente esta mensagem quando o cliente entrar em contato pela primeira vez: \"#{data[:greeting_message]}\"" : "MENSAGEM DE SAUDAÇÃO: Crie uma saudação natural e acolhedora alinhada com a identidade e tom de voz definidos acima."

    user_content = <<~USER
      Crie o prompt de sistema para a IA da clínica usando estas diretrizes:
      1. Identidade e Tom de Voz: #{data[:identity]}
      2. Informações da Clínica (Horários, Especialidades, Diferenciais, Convênios): #{data[:institutional]}
      3. FAQ (Perguntas frequentes dos pacientes): #{data[:faq]}
      4. #{greeting_instruction}
      5. Modo de Atuação: #{role_instruction}
      6. Regras de Agendamento: #{schedule_instruction}
      7. Tratamento do Paciente: #{name_instruction}
      8. Estilo de Comunicação: #{emoji_instruction}
      9. Ações Proibidas: #{prohibitions_instruction}
      10. Triagem (Dados obrigatórios a coletar antes de sugerir especialidade ou agendar): #{data[:sdr_rules]}
      11. Regras de Transbordo (Quando transferir para atendente humano): #{data[:routing_rules]}

      IMPORTANTE: O prompt deve ser específico para clínica de saúde. Use termos como "paciente" (não "cliente"), "consulta" (não "visita"), "profissional de saúde" (não "corretor"). A IA deve ser acolhedora, clara e transmitir segurança. Nunca invente informações sobre saúde que não foram fornecidas. Siga rigorosamente as regras de agendamento e nunca pergunte o telefone do paciente.
    USER

    begin
      api_key = GlobalSetting.fetch('openai_api_key').presence || ENV['OPENAI_API_KEY']
      client = OpenAI::Client.new(access_token: api_key)
      
      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_content }
          ],
          temperature: 0.7
        }
      )
      
      generated_text = response.dig("choices", 0, "message", "content")
      render json: { prompt: generated_text }
    rescue StandardError => e
      Rails.logger.error("Error generating prompt: #{e.message}")
      render json: { error: "Erro ao gerar prompt na OpenAI." }, status: :unprocessable_entity
    end
  end

  private
    def set_inbox
      @inbox = current_user.account.inboxes.find(params[:id])
    end

    def inbox_params
      params.require(:inbox).permit(:name, :provider, :phone_number, :api_url, :api_key, :bot_prompt, :ai_enabled, :ai_name, :ai_prompt, :ai_temperature, :working_hours_enabled, :out_of_office_message, :followup_enabled, :followup_max_attempts, :followup_wait_time_minutes, :followup_send_closing_message, :followup_closing_message, working_hours: [:day, :open, :start, :end])
    end
end
