class AppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.includes(:contact, :professional, :service).find_by(id: appointment_id)
    return unless appointment
    return if appointment.status.in?(%w[cancelado cancelled])
    return if appointment.reminder_sent_at.present?

    inbox = appointment.account.inboxes.first
    return unless inbox

    contact = appointment.contact
    phone = normalize_phone(contact&.phone)
    return if phone.blank?

    professional = appointment.professional
    service = appointment.service

    date_str = appointment.appointment_date&.strftime('%d/%m/%Y')
    time_str = appointment.start_time

    message = build_reminder(contact, professional, service, date_str, time_str)

    sent = send_whatsapp(inbox, phone, message)
    appointment.update_columns(reminder_sent_at: Time.current) if sent
  end

  private

  def build_reminder(contact, professional, service, date, time)
    patient_name = contact.first_name.presence || contact.name
    prof_name    = professional&.name || 'nosso profissional'
    serv_name    = service&.name || 'consulta'

    <<~MSG.strip
      Olá, #{patient_name}! 😊

      Passando para lembrar que você tem uma *#{serv_name}* hoje com *#{prof_name}* às *#{time}*.

      Você vai conseguir comparecer? Por favor, me confirme respondendo:

      👉 *SIM* — para confirmar sua presença ✅
      👉 *NÃO* — para cancelar ❌

      Qualquer dúvida é só chamar aqui!
    MSG
  end

  def normalize_phone(phone)
    return nil if phone.blank?
    digits = phone.gsub(/\D/, '')
    digits = "55#{digits}" if digits.length <= 11 && !digits.start_with?('55')
    digits
  end

  def resolve_jid(svc, digits)
    jid = svc.resolve_jid(digits)
    return jid if jid.present?

    if digits.start_with?('55') && digits.length == 13
      ddd = digits[2..3]; number = digits[4..]
      if number.start_with?('9') && number.length == 9
        jid = svc.resolve_jid("55#{ddd}#{number[1..]}")
        return jid if jid.present?
      end
    end

    if digits.start_with?('55') && digits.length == 12
      ddd = digits[2..3]; number = digits[4..]
      if number.length == 8
        jid = svc.resolve_jid("55#{ddd}9#{number}")
        return jid if jid.present?
      end
    end

    nil
  end

  def send_whatsapp(inbox, phone, message)
    svc = WhatsappBaileysService.new(inbox)
    jid = resolve_jid(svc, phone)
    unless jid.present?
      Rails.logger.warn "[AppointmentReminderJob] Número #{phone} não encontrado no WhatsApp"
      return false
    end
    result = svc.send_message(jid, message)
    result.present?
  rescue => e
    Rails.logger.error "[AppointmentReminderJob] Falha ao enviar WhatsApp: #{e.message}"
    false
  end
end
